class Report::Tags < Report::Base

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

    filepath = "reports/reports_data/report-#{report.id}-processed-input.csv"
    FileManager.save_file filepath, csv_string
    report.processed_input = filepath

    report.processed_csv.each do |row|
      report.steps << [row[1], []]
    end

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

    tags_publishers = {}
    publishers_media = {}

    report.processed_csv.each do |row|
      tag_id = row[1].to_i
      step_index = report.steps.index{|r| r[0].to_i == tag_id}


      tag_media_ids = MediaTag.where(tag_id: tag_id).pluck(:media_id)
      media = Media.in(id: tag_media_ids)
      media = media.gte(created_time: report.date_from) if report.date_from
      media = media.lte(created_time: report.date_to) if report.date_to

      media_ids = media.pluck(:id, :user_id).uniq{|r| r.last}
      publishers_ids = media_ids.map(&:last)
      tags_publishers[tag_id] = publishers_ids

      publishers_media[tag_id] = {}
      media_ids.each { |r| publishers_media[tag_id][r[1]] = r[0] }

      unless report.steps[step_index][1].include?('publishers_info')
        users = []
        publishers_ids.in_groups_of(5_000, false) do |ids|
          users.concat User.in(id: ids).outdated.pluck(:id)
        end
        if users.size == 0
          report.steps[step_index][1] << 'publishers_info'
        else
          users.each { |uid| UserWorker.perform_async uid }
        end
      end

      if report.steps[step_index][1].include?('publishers_info')
        if report.output_data.include?('likes') && !report.steps[step_index][1].include?('likes')
          get_likes = User.in(id: publishers_ids).without_likes.with_media.not_private.pluck(:id)
          if get_likes.size == 0
            report.steps[step_index][1] << 'likes'
          else
            get_likes.each { |uid| UserAvgLikesWorker.perform_async uid }
          end
        end

        if report.output_data.include?('location') && !report.steps[step_index][1].include?('location')
          get_location = User.in(id: publishers_ids).without_location.with_media.not_private.pluck(:id)
          if get_location.size == 0
            report.steps[step_index][1] << 'location'
          else
            get_location.each { |uid| UserLocationWorker.perform_async uid }
          end
        end

        if report.output_data.include?('feedly') && !report.steps[step_index][1].include?('feedly')
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
            no_feedly.each { |uid| UserFeedlyWorker.new.perform uid }
            progress += feedly_exists.size / with_website.size.to_f / parts_amount
          end
        end
      end
    end

    report.progress = ((report.steps.inject(0) { |sum, tag_data| sum + tag_data[1].size}.to_f / (report.processed_csv.size*parts_amount)).round(2) * 100).to_i

    if report.progress == 100
      report.status = 'finished'
      self.finish report, tags_publishers, publishers_media
    end

    report.save
  end


  def self.finish report, tags_publishers, publishers_media
    files = []

    header = ['ID', 'Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followers', 'Email']
    header += ['Country', 'State', 'City'] if report.output_data.include? 'location'
    header += ['AVG Likes'] if report.output_data.include? 'likes'
    header += ['Feedly Subscribers'] if report.output_data.include? 'feedly'
    header += ['Media Link', 'Media Likes', 'Media Comments']

    report.processed_csv.each do |row|
      tag_id = row[1].to_i
      tag = Tag.find(tag_id)

      media_list = {}
      publishers_media[tag_id].values.in_groups_of(10_000, false) do |rows|
        Media.in(id: rows).pluck(:user_id, :likes_amount, :comments_amount, :link).each do |media_row|
          user_id = media_row.shift
          media_list[user_id] = media_row
        end
      end

      csv_string = CSV.generate do |csv|
        csv << header
        tags_publishers[tag_id].in_groups_of(1000, false) do |ids|
          User.in(id: ids).each do |u|
            media = media_list[u.id]
            next unless media
            row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
            row += [u.location_country, u.location_state, u.location_city] if report.output_data.include? 'location'
            row += [u.avg_likes] if report.output_data.include? 'likes'
            if report.output_data.include? 'feedly'
              feedly = u.feedly
              row += [feedly ? feedly.subscribers_amount : '']
            end
            row += [media[2], media[0], media[1]]

            csv << row
          end
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

      filepath = "reports/tag-#{report.processed_csv.size}-publishers-#{Time.now.to_i}.zip"
      FileManager.save_file filepath, binary_data
      report.result_data = filepath
    end

    report.finished_at = Time.now
    report.save

    ReportMailer.users(report.id).deliver if report.notify_email.present?
  end
end