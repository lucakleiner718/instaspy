module Report::Followers

  def self.reports_new report
    processed_input = report.original_csv
    processed_input.map! do |row|
      user = User.get(row[0])
      if user
        [row[0], user.id]
      else
        report.not_processed << row[0]
        []
      end
    end
    processed_input.select! { |r| r[0].present? }

    csv_string = CSV.generate do |csv|
      processed_input.each do |row|
        csv << row
      end
    end
    File.write(Rails.root.join("public", "reports/reports_data/report-#{report.id}-processed-input.csv"), csv_string)
    report.processed_input ="reports/reports_data/report-#{report.id}-processed-input.csv"

    report.data = { 'followers' => [] }
    report.status = :in_process
    report.started_at = Time.now
    report.save
  end


  def self.reports_in_process report
    parts_amount = 3
    ['likes', 'location', 'feedly'].each do |info|
      parts_amount += 1 if report.output_data.include?(info)
    end

    progress = 0

    unless report.steps.include?('user_info')
      not_updated = User.where(id: report.processed_ids).where('grabbed_at < ?', 6.hours.ago).pluck(:id)

      if not_updated.size == 0
        report.steps << 'user_info'
      else
        not_updated.each do |uid|
          UserWorker.perform_async uid, true
        end

        progress += (report.processed_ids.size - not_updated.size) / report.processed_ids.size.to_f / parts_amount
      end
    end

    if report.steps.include?('user_info')
      unless report.steps.include?('followers')
        users = User.where(id: report.processed_ids).where(private: false).map{|u| [u.id, u.followed_by, Follower.where(user_id: u.id).size]}
        for_update = users.select{|r| r[2]/r[1].to_f < 0.95}

        if for_update.size == 0
          report.steps << 'followers'
        else
          for_update.each do |row|
            UserFollowersWorker.perform_async(row[0], ignore_exists: true)
          end
          progress += (users.size - for_update.size) / users.size.to_f/ parts_amount
        end
      end

      if report.steps.include?('followers')
        if report.data['followers'].size == 0
          # ids of ALL followers of provided users
          followers_ids = Follower.where(user_id: report.processed_ids)
          followers_ids = followers_ids.where('followed_at >= ?', report.date_from) if report.date_from
          followers_ids = followers_ids.where('followed_at <= ?', report.date_to) if report.date_to
          followers_ids = followers_ids.pluck(:follower_id).uniq

          report.data['followers'] = followers_ids
        else
          followers_ids = report.data['followers']
        end

        # update followers info, so in report we will have actual media amount, followers and etc. data
        unless report.steps.include?('followers_info')
          not_updated = []
          followers_ids.in_groups_of(10_000, false) do |ids|
            users = User.where(id: ids).outdated(7.days).pluck(:id, :grabbed_at)
            not_updated.concat users.select{|r| r[1].blank? || r[1] < 8.days.ago}.map(&:first)
          end
          if not_updated.size == 0
            report.steps << 'followers_info'
          else
            not_updated.each { |uid| UserWorker.perform_async uid, true }
            progress += (followers_ids.size - not_updated.size) / followers_ids.size.to_f / parts_amount
          end
        end

        # after followers list grabbed and all followers updated
        if report.steps.include?('followers_info')

          # if we need avg likes data and it is not yet grabbed
          if report.output_data.include?('likes') && !report.steps.include?('likes')
            get_likes = []
            followers_ids.in_groups_of(5_000, false) do |ids|
              get_likes.concat User.where(id: ids).without_likes.with_media.pluck(:id)
            end
            if get_likes.size == 0
              report.steps << 'likes'
            else
              get_likes.each { |uid| UserAvgLikesWorker.perform_async uid }
              progress += (followers_ids.size - get_likes.size) / followers_ids.size.to_f / parts_amount
            end
          end

          # if we need location data and it is not yet grabbed
          if report.output_data.include?('location') && !report.steps.include?('location')
            get_location = []
            followers_ids.in_groups_of(5_000, false) do |ids|
              get_location.concat User.where(id: ids).without_location.with_media.pluck(:id)
            end
            if get_location.size == 0
              report.steps << 'location'
            else
              get_location.each { |uid| UserLocationWorker.perform_async(uid) }
              progress += (followers_ids.size - get_location.size) / followers_ids.size.to_f / parts_amount
            end
          end

          # if we need feedly subscribers amount and it is not yet grabbed
          if report.output_data.include?('feedly') && !report.steps.include?('feedly')
            with_website = []
            feedly_exists = []
            followers_ids.in_groups_of(5_000, false) do |ids|
              for_process = User.where(id: ids).with_url.pluck(:id)
              with_website.concat for_process
              feedly_exists.concat Feedly.where(user_id: for_process).pluck(:user_id)
            end

            no_feedly = with_website - feedly_exists

            if no_feedly.size == 0
              report.steps << 'feedly'
            else
              no_feedly.each { |uid| UserFeedlyWorker.perform_async uid }
              progress += feedly_exists.size / with_website.size.to_f / parts_amount
            end
          end
        end
      end
    end

    progress += report.steps.size.to_f / parts_amount

    report.progress = progress.round(2) * 100

    if parts_amount == report.steps.size
      report.status = 'finished'
      self.finish report
    end

    report.save
  end


  def self.finish report
    files = []

    header = ['ID', 'Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followers', 'Email']
    header += ['Country', 'State', 'City'] if report.output_data.include? 'location'
    header += ['AVG Likes'] if report.output_data.include? 'likes'
    header += ['Feedly Subscribers'] if report.output_data.include? 'feedly'

    User.where(id: report.processed_ids).find_each do |user|
      csv_string = CSV.generate do |csv|
        csv << header
        followers_ids = Follower.where(user_id: user.id).pluck(:follower_id)
        User.where(id: followers_ids).each do |u|
          row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
          row.concat [u.location_country, u.location_state, u.location_city] if report.output_data.include? 'location'
          row.concat [u.avg_likes] if report.output_data.include? 'likes'
          if report.output_data.include? 'feedly'
            feedly = u.feedly
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
      File.write("public/#{filepath}", binary_data)
      report.result_data = filepath
    end

    report.finished_at = Time.now
    report.save

    ReportMailer.followers(report.id).deliver if report.notify_email.present?
  end
end