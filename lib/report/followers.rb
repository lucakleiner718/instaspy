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
        for_update = users.select{|r| r[2]/r[1].to_f < 0.95 || r[2]/r[1].to_f > 1.1}

        if for_update.size == 0
          @report.steps << 'followers'
        else
          for_update.map do |row|
            UserFollowersWorker.perform_async row[0], ignore_exists: true #, skip_exists: row[2]/row[1].to_f < 1.1
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
          FileManager.save_file filepath, content: followers_ids.join(',')
          @report.data['followers_file'] = filepath

          @report.amounts[:followers] = followers_ids.size
        else
          followers_ids = FileManager.read_file(@report.data['followers_file']).split(',')
        end

        # update followers info, so in report we will have actual media amount, followers and etc. data
        unless @report.steps.include?('followers_info')
          if @report.data['followers_to_update']
            followers_to_update = FileManager.read_file(@report.data['followers_to_update']).split(',')
          else
            followers_to_update = followers_ids
          end

          not_updated = []
          followers_to_update.in_groups_of(10_000, false) do |ids|
            # grab all users without data and data outdated for 7 days
            users = User.in(id: ids).outdated(7.days).pluck(:id, :grabbed_at)
            # select users only without data and outdated for 8 days, to avoid adding new users on each iteration
            list = users.select{|r| r[1].blank? || r[1] < 8.days.ago}.map(&:first)
            if list.size > 0
              not_updated.concat list
              list.each { |uid| UserWorker.perform_async uid }
            end
          end

          filepath = "reports/reports_data/report-#{@report.id}-followers-to-update"
          if not_updated.size == 0
            FileManager.delete_file filepath if @report.data['followers_to_update']
            @report.data.delete('followers_to_update')
            @report.steps << 'followers_info'
          else
            FileManager.save_file filepath, content: not_updated.join(',')
            @report.data['followers_to_update'] = filepath
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

    @report.save

    if @parts_amount == @report.steps.size
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
    header.slice! 4,1 if @report.output_data.include? 'slim'

    User.in(id: @report.processed_ids).each do |user|
      filename = "#{@report.id}-#{user.username}-followers.csv"
      unless File.exists? Rails.root.join('tmp', filename)
        csv_string = CSV.generate do |csv|
          csv << header
          followers_ids = Follower.where(user_id: user.id).pluck(:follower_id).uniq
          followers = User.in(id: followers_ids)
          followers = followers.ne(email: nil).gte(followed_by: 1_000) if @report.output_data.include? 'slim'
          followers.each do |u|
            row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
            row.slice! 4,1 if @report.output_data.include? 'slim'
            row.concat [u.location_country, u.location_state, u.location_city] if @report.output_data.include? 'location'
            row.concat [u.avg_likes] if @report.output_data.include? 'likes'
            if @report.output_data.include? 'feedly'
              feedly = u.feedly.first
              row.concat [feedly ? feedly.subscribers_amount : '']
            end

            csv << row
          end
        end

        File.write Rails.root.join('tmp', filename), csv_string
      end
      files << filename
    end

    if files.size > 0
      zipfilename = Rails.root.join("tmp", "followers-report-#{Time.now.to_i}.zip")
      Zip::File.open(zipfilename, Zip::File::CREATE) do |zipfile|
        files.each do |filename|
          zipfile.add(filename, Rails.root.join('tmp', filename))
        end
      end

      filepath = "reports/users-followers-#{files.size}-#{Time.now.to_i}.zip"
      FileManager.save_file filepath, file: zipfilename
      @report.result_data = filepath

      File.delete(zipfilename)
      files.each { |filename| File.delete(Rails.root.join('tmp', filename)) }
    end

    @report.finished_at = Time.now
    @report.status = :finished
    @report.save

    ReportMailer.followers(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end
end