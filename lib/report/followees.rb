class Report::Followees < Report::Base

  def reports_in_process
    @parts_amount = 3
    ['likes', 'location', 'feedly'].each do |info|
      @parts_amount += 1 if @report.output_data.include?(info)
    end

    self.process_user_info

    if @report.steps.include?('user_info')
      unless @report.steps.include?('followees')
        users = User.where(id: @report.processed_ids).not_private.where("followees_updated_at is null OR followees_updated_at < ?", 3.days.ago).map{ |u| [u.id, u.follows, u.followees_size] }
        for_update = users.select{|r| r[2]/r[1].to_f < 0.95 || r[2]/r[1].to_f > 1.2 }

        if for_update.size == 0
          @report.steps << 'followees'
        else
          for_update.each { |row| UserFolloweesWorker.perform_async(row[0], ignore_exists: true) }
          @progress += (users.size - for_update.size) / users.size.to_f/ @parts_amount
        end
      end

      if @report.steps.include?('followees')

        if @report.data['followees_file'].blank?
          # ids of ALL followees of provided users
          followees_ids = Follower.where(follower_id: @report.processed_ids)
          followees_ids = followees_ids.where("followed_at >= ?", @report.date_from) if @report.date_from.present?
          followees_ids = followees_ids.where("followed_at <= ?", @report.date_to) if @report.date_to.present?
          followees_ids = followees_ids.pluck(:user_id).uniq

          filepath = "reports/reports_data/report-#{@report.id}-followees-ids"
          FileManager.save_file filepath, content: followees_ids.join(',')
          @report.data['followees_file'] = filepath

          @report.amounts[:followees] = followees_ids.size
          @report.save
        else
          followees_ids = FileManager.read_file(@report.data['followees_file']).split(',')
        end

        # update followees info, so in report we will have actual media amount, followees and etc. data
        unless @report.steps.include?('followees_info')
          not_updated = []
          followees_ids.in_groups_of(10_000, false) do |ids|
            users = User.where(id: ids).outdated(7.days).pluck(:id, :grabbed_at)
            not_updated.concat users.select{|r| r[1].blank? || r[1] < 8.days.ago}.map(&:first)
          end
          if not_updated.size == 0
            @report.steps << 'followees_info'
          else
            not_updated.each { |uid| UserWorker.perform_async uid }
            @progress += (followees_ids.size - not_updated.size) / followees_ids.size.to_f / @parts_amount
          end
        end

        # after followees list grabbed and all followees updated
        if @report.steps.include?('followees_info')
          self.process_likes followees_ids
          self.process_location followees_ids
          self.process_feedly followees_ids
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
    header.slice! 4,1 if @report.output_data.include?('slim') || @report.output_data.include?('slim_followers')
    header += ['Relation']

    User.where(id: @report.processed_ids).each do |user|
      csv_string = CSV.generate do |csv|
        csv << header
        followees_ids = Follower.where(follower_id: user.id).pluck(:user_id)
        followees = User.where(id: followees_ids)
        followees = followees.where("email is not null").where("followed_by >= ?", 1_000) if @report.output_data.include? 'slim'
        followees = followees.where("followed_by >= ?", 1_000) if @report.output_data.include? 'slim_followers'
        followees.each do |u|
          row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
          row.slice! 4,1 if @report.output_data.include? 'slim' || @report.output_data.include?('slim_followers')
          row.concat [u.location_country, u.location_state, u.location_city] if @report.output_data.include? 'location'
          row.concat [u.avg_likes] if @report.output_data.include? 'likes'
          if @report.output_data.include? 'feedly'
            feedly = u.feedly.first
            row.concat [feedly ? feedly.subscribers_amount : '']
          end
          row << user.username

          csv << row
        end
      end

      files << ["#{user.username}-followees-#{Time.now.to_i}.csv", csv_string]
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

      filepath = "reports/users-followees-#{files.size}-#{Time.now.to_i}.zip"
      FileManager.save_file filepath, content: binary_data
      @report.result_data = filepath
    end

    @report.finished_at = Time.now
    @report.save

    ReportMailer.followees(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end
end
