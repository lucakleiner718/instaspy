module Report::Tags

  def self.reports_new report
    processed_input = report.original_csv
    processed_input.map! do |row|
      tag = Tag.get(row[0])
      if tag
        [row[0], tag.id]
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

    report.processed_csv.each do |row|
      report.steps << [row[1], []]
    end

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

    tags_publishers = {}

    report.processed_csv.each do |row|
      tag_id = row[1].to_i
      step_index = report.steps.index{|r| r[0].to_i == tag_id}

      tag_media_ids = Tag.connection.execute("select media_id from media_tags where tag_id=#{tag_id}").to_a.map(&:first)
      media = Media.where(id: tag_media_ids)
      media = media.where('created_time >= ?', report.date_from) if report.date_from
      media = media.where('created_time <= ?', report.date_to) if report.date_to

      publishers_ids = media.pluck(:user_id).uniq
      tags_publishers[tag_id] = publishers_ids

      unless report.steps[step_index][1].include?('publishers_info')
        users = []
        publishers_ids.in_groups_of(5_000, false) do |ids|
          users.concat User.where(id: ids).outdated.pluck(:id)
        end
        if users.size == 0
          report.steps[step_index][1] << 'publishers_info'
        else
          users.each { |uid| UserWorker.perform_async uid }
        end
      end

      if report.steps[step_index][1].include?('publishers_info')
        if report.output_data.include?('likes') && !report.steps[step_index][1].include?('likes')
          get_likes = User.where(id: publishers_ids).without_likes.with_media.pluck(:id)
          if get_likes.size == 0
            report.steps[step_index][1] << 'likes'
          else
            get_likes.each { |uid| UserAvgLikesWorker.perform_async uid }
          end
        end

        if report.output_data.include?('location') && !report.steps[step_index][1].include?('location')
          get_location = User.where(id: publishers_ids).without_location.with_media.pluck(:id)
          if get_location.size == 0
            report.steps[step_index][1] << 'location'
          else
            get_location.each { |uid| UserLocationWorker.perform_async uid }
          end
        end
      end
    end

    report.progress = ((report.steps.inject(0) { |sum, tag_data| sum + tag_data[1].size}.to_f / (report.processed_csv.size*parts_amount)).round(2) * 100).to_i

    # if report.steps.select{|r| r[1].include?('publishers_info')}.size == report.steps.size
    if report.progress == 100
      report.status = 'finished'
      self.finish report, tags_publishers
    end

    report.save
  end


  def self.finish report, tags_publishers
    files = []

    header = ['ID', 'Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followers', 'Email']
    header += ['Country', 'State', 'City'] if report.output_data.include? 'location'
    header += ['AVG Likes'] if report.output_data.include? 'likes'
    header += ['Feedly Subscribers'] if report.output_data.include? 'feedly'

    report.processed_csv.each do |row|
      tag_id = row[1].to_i
      tag = Tag.find(tag_id)

      csv_string = CSV.generate do |csv|
        csv << header
        User.where(id: tags_publishers[tag_id]).find_each do |u|
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

      files << ["tag-#{tag.name}-publishers-#{Time.now.to_i}.csv", csv_string]
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

      filepath = "reports/tag-#{report.processed_csv.size}-publishers.zip"
      File.write("public/#{filepath}", binary_data)
      report.result_data = filepath
    end

    report.finished_at = Time.now
    report.save

    ReportMailer.users(report.id).deliver if report.notify_email.present?
  end
end