module Report::Users

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
    report.update_attribute :processed_input, "reports/reports_data/report-#{report.id}-processed-input.csv"

    ReportProcessProgressWorker.perform_async report.id

    report.status = :in_process
    report.started_at = Time.now
    report.save
  end


  def self.reports_in_process report
    parts_amount = 1
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

        progress += not_updated.size / report.processed_ids.size.to_f / parts_amount
      end
    end

    if report.steps.include?('user_info')
      if report.output_data.include?('likes') && !report.steps.include?('likes')
        get_likes = User.where(id: report.processed_ids).without_likes.with_media.pluck(:id)
        if get_likes.size == 0
          report.steps << 'likes'
        else
          get_likes.each { |uid| UserAvgLikesWorker.perform_async uid }
        end
      end

      if report.output_data.include?('location') && !report.steps.include?('location')
        get_location = User.where(id: report.processed_ids).without_location.with_media.pluck(:id)
        if get_location.size == 0
          report.steps << 'location'
        else
          get_location.each { |uid| UserLocationWorker.perform_async uid }
        end
      end

      if report.output_data.include?('feedly') && !report.steps.include?('feedly')
        if report.jobs['feedly']
          feedly_jobs = report.jobs['feedly']
          jobs = feedly_jobs.map { |job_id| Sidekiq::Status::get_all job_id }
          if jobs.select{|j| j['status'] == 'complete'}.size == feedly_jobs.size
            # complete
            report.steps << 'feedly'
          else
            # waiting and changing progress amount
            progress += (jobs.size - jobs.select{|j| j['status'] == 'complete'}.size) / jobs.size.to_f / parts_amount
          end
        else
          job_ids = []
          # adding workers
          User.where(id: report.processed_ids).with_url.find_each do |u|
            job_id << FeedlyWorker.perform_async(u.website)
            if job_id
              job_ids << job_id
            else
              FeedlyWorker.new.perform(u.website)
            end
          end

          report.jobs['feedly'] = job_ids
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

    csv_string = CSV.generate do |csv|
      csv << header
      User.where(id: report.processed_ids).find_each do |u|
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

    basename = "users-#{report.processed_ids.size}-report-#{Time.now.to_i}"

    files << ["#{basename}.csv", csv_string]

    if files.size > 0
      stringio = Zip::OutputStream.write_buffer do |zio|
        files.each do |file|
          zio.put_next_entry(file[0])
          zio.write file[1]
        end
      end
      stringio.rewind
      binary_data = stringio.sysread

      filepath = "reports/#{basename}.zip"
      File.write("public/#{filepath}", binary_data)
      report.result_data = filepath
    end

    report.finished_at = Time.now
    report.save

    ReportMailer.users(report.id).deliver if report.notify_email.present?
  end
end