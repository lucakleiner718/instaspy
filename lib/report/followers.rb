module Report::Followers

  def self.reports_new report
    ids = []
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
    report.update_attribute :processed_input, "reports/reports_data/report-#{report.id}-processed-input.csv"

    processed_input.each do |row|
      user = User.find(row[1])
      ids << UserFollowersWorker.perform_async(user.id, ignore_exists: true)
    end

    report.status = :in_process
    report.jobs = { followers: ids }
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
      not_updated.each do |uid|
        UserWorker.perform_async uid, true
      end

      progress += not_updated / report.processed_ids.to_f / parts_amount
    end

    if report.steps.include?('user_info')
      unless report.steps.include?('followers')
        followers_jobs = report.jobs['followers'].split(',')
        followers_jobs.map! do |job_id|
          Sidekiq::Status::get_all job_id
        end
        followers_job_progress = followers_jobs.map{|r| r['status'] == 'complete'}.size / followers_jobs.size.to_f * 100
        if followers_job_progress == 100
          report.steps << 'followers'
        end
      end

      followers_ids = Follower.where(user_id: report.processed_ids).pluck(:follower_id)

      unless report.steps.include?('followers_info')
        not_updated = User.where(id: followers_ids).outdated.pluck(:id)
        if not_updated.size == 0
          report.steps << 'followers_info'
        else
          not_updated.each { |uid| UserWorker.perform_async uid, true }
        end
      end

      if report.steps.include?('followers') && report.steps.include?('followers_info')
        if report.output_data.include?('likes') && !report.steps.include?('likes')
          get_likes = User.where(id: followers_ids).without_likes.with_media.pluck(:id)
          if get_likes.size == 0
            report.steps << 'likes'
          else
            get_likes.each { |uid| UserAvgLikesWorker.perform_async uid }
          end
        end

        if report.output_data.include?('location') && !report.steps.include?('location')
          get_location = User.where(id: followers_ids).without_location.with_media.pluck(:id)
          if get_location.size == 0
            report.steps << 'location'
          else
            get_location.each { |uid| UserLocationWorker.perform_async uid }
          end
        end

        if report.output_data.include?('feedly') && !report.steps.include?('feedly')

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
      report.save
    end

    ReportMailer.finished(report.id).deliver if report.notify_email.present?
  end
end