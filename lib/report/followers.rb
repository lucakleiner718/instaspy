class Report::Followers < Report::Base

  def reports_in_process
    @parts_amount = 3
    ['likes', 'location', 'feedly'].each do |info|
      @parts_amount += 1 if @report.output_data.include?(info)
    end

    self.process_user_info

    if @report.steps.include?('user_info')
      unless @report.steps.include?('followers')
        users = User.in(id: @report.processed_ids).where(private: false).map{|u| [u.id, u.followed_by, u.followers_size]}
        for_update = users.select{|r| r[2]/r[1].to_f < 0.95}

        if for_update.size == 0
          @report.steps << 'followers'
        else
          for_update.each do |row|
            UserFollowersWorker.perform_async(row[0], ignore_exists: true)
          end
          @progress += (users.size - for_update.size) / users.size.to_f / @parts_amount
        end
      end

      if @report.steps.include?('followers')

        if @report.data['followers_file'].blank?
          # ids of ALL followers of provided users
          followers_ids = Follower.in(user_id: @report.processed_ids)
          followers_ids = followers_ids.gte(followed_at: @report.date_from) if @report.date_from
          followers_ids = followers_ids.lte(followed_at: @report.date_to) if @report.date_to
          followers_ids = followers_ids.pluck(:follower_id).uniq

          filepath = "reports/reports_data/report-#{@report.id}-followers-ids"
          FileManager.save_file filepath, followers_ids.join(',')
          @report.data['followers_file'] = filepath
        else
          followers_ids = FileManager.read_file(@report.data['followers_file']).split(',')
        end

        # update followers info, so in report we will have actual media amount, followers and etc. data
        unless @report.steps.include?('followers_info')
          not_updated = []
          followers_ids.in_groups_of(10_000, false) do |ids|
            # grab all users without data and data outdated for 7 days
            users = User.in(id: ids).outdated(7.days).pluck(:id, :grabbed_at)
            # select users only without data and outdated for 8 days, to avoid adding new users on each iteration
            not_updated.concat users.select{|r| r[1].blank? || r[1] < 8.days.ago}.map(&:first)
          end
          if not_updated.size == 0
            @report.steps << 'followers_info'
          else
            not_updated.each { |uid| UserWorker.perform_async uid }
            @progress += (followers_ids.size - not_updated.size) / followers_ids.size.to_f / @parts_amount
          end
        end

        # after followers list grabbed and all followers updated
        if @report.steps.include?('followers_info')
          self.process_likes followers_ids
          self.process_location followers_ids
          self.process_feedly followers_ids
        end
      end
    end

    @progress += @report.steps.size.to_f / @parts_amount

    @report.progress = @progress.round(2) * 100

    if @parts_amount == @report.steps.size
      @report.status = 'finished'
      self.finish
    end

    @report.save
  end

  def finish
    files = []

    header = ['ID', 'Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followers', 'Email']
    header += ['Country', 'State', 'City'] if @report.output_data.include? 'location'
    header += ['AVG Likes'] if @report.output_data.include? 'likes'
    header += ['Feedly Subscribers'] if @report.output_data.include? 'feedly'

    User.in(id: @report.processed_ids).each do |user|
      csv_string = CSV.generate do |csv|
        csv << header
        followers_ids = Follower.where(user_id: user.id).pluck(:follower_id)
        User.in(id: followers_ids).each do |u|
          row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
          row.concat [u.location_country, u.location_state, u.location_city] if @report.output_data.include? 'location'
          row.concat [u.avg_likes] if @report.output_data.include? 'likes'
          if @report.output_data.include? 'feedly'
            feedly = u.feedly.first
            row.concat [feedly ? feedly.subscribers_amount : '']
          end

          csv << row
        end
      end

      files << ["#{user.username}-followers-#{Time.now.to_i}.csv", csv_string]
    end

    if files.size > 0
      stringio = Zip::OutputStream.write_buffer do |zio|
        files.each do |file|
          zio.put_next_entry(file[0])
          zio.write file[1]
        end
      end
      stringio.rewind
      binary_data = stringio.sysread

      filepath = "reports/users-followers-#{files.size}-#{Time.now.to_i}.zip"
      FileManager.save_file filepath, binary_data
      @report.result_data = filepath
    end

    @report.finished_at = Time.now
    @report.save

    ReportMailer.followers(@report.id).deliver if @report.notify_email.present?
  end
end