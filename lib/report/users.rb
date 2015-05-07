class Report::Users < Report::Base

  def self.reports_new report
    processed_input = report.original_csv.map(&:first)

    insta_ids = processed_input.select{|r| r.numeric?}.map(&:to_i)
    usernames = processed_input - insta_ids

    processed_data = []

    if insta_ids.size > 0
      found_insta_ids = User.in(insta_id: insta_ids).pluck(:insta_id, :id)
      (insta_ids - found_insta_ids.map(&:first)).each do |insta_id|
        u = User.create(insta_id: insta_id)
        found_insta_ids << [u.insta_id, u.id] if u && u.valid?
      end
      processed_data.concat found_insta_ids
    end

    if usernames.size > 0
      found_usernames = User.in(username: usernames).pluck(:username, :id)
      (usernames - found_usernames.map(&:first)).each do |username|
        u = User.get(username)
        found_usernames << [u.username, u.id] if u && u.valid?
      end
      processed_data.concat found_usernames
    end

    csv_string = CSV.generate do |csv|
      processed_data.each do |row|
        csv << row
      end
    end

    filepath = "reports/reports_data/report-#{report.id}-processed-input.csv"
    FileManager.save_file filepath, csv_string
    report.processed_input = filepath

    report.status = :in_process
    report.started_at = Time.now
    report.save

    ReportProcessProgressWorker.perform_async report.id
  end


  def self.reports_in_process report
    parts_amount = 1
    ['likes', 'location', 'feedly'].each do |info|
      parts_amount += 1 if report.output_data.include?(info)
    end

    progress = 0

    unless report.steps.include?('user_info')
      users = User.in(id: report.processed_ids).outdated(1.day).pluck(:id, :grabbed_at)
      not_updated = users.select{|r| r[1].blank? || r[1] < 36.hours.ago}.map(&:first)

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
        get_likes = User.in(id: report.processed_ids).without_likes.with_media.not_private.pluck(:id)
        if get_likes.size == 0
          report.steps << 'likes'
        else
          get_likes.each { |uid| UserAvgLikesWorker.perform_async uid }
        end
      end

      if report.output_data.include?('location') && !report.steps.include?('location')
        get_location = User.in(id: report.processed_ids).without_location.with_media.not_private.pluck(:id)
        if get_location.size == 0
          report.steps << 'location'
        else
          get_location.each { |uid| UserLocationWorker.perform_async uid }
        end
      end

      if report.output_data.include?('feedly') && !report.steps.include?('feedly')
        with_website = []
        feedly_exists = []
        report.processed_ids.in_groups_of(5_000, false) do |ids|
          for_process = User.in(id: ids).with_url.pluck(:id)
          with_website.concat for_process
          feedly_exists.concat Feedly.in(user_id: for_process).pluck(:user_id)
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
      User.in(id: report.processed_ids).each do |u|
        row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
        row.concat [u.location_country, u.location_state, u.location_city] if report.output_data.include? 'location'
        row.concat [u.avg_likes] if report.output_data.include? 'likes'
        if report.output_data.include? 'feedly'
          feedly = u.feedly.first
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
      FileManager.save_file filepath, binary_data
      report.result_data = filepath
    end

    report.finished_at = Time.now
    report.save

    ReportMailer.users(report.id).deliver if report.notify_email.present?
  end
end