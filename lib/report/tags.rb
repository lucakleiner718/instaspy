class Report::Tags < Report::Base

  def reports_new
    processed_input = @report.original_csv.map(&:first).map(&:downcase)

    tags = Tag.in(name: processed_input).pluck(:name, :id)

    (processed_input - tags.map(&:first)).each do |tag|
      t = Tag.get(tag)
      tags << [t.name, t.id] if t
    end

    csv_string = CSV.generate do |csv|
      tags.each do |row|
        csv << row
      end
    end

    filepath = "reports/reports_data/report-#{@report.id}-processed-input.csv"
    FileManager.save_file filepath, content: csv_string
    @report.processed_input = filepath

    @report.processed_csv.each do |row|
      @report.steps << [row[1], []]
    end

    @report.status = :in_process
    @report.started_at = Time.now
    @report.save

    ReportProcessProgressWorker.perform_async @report.id
  end

  def reports_in_process
    @parts_amount = 2
    ['likes', 'location', 'feedly'].each do |info|
      @parts_amount += 1 if @report.output_data.include?(info)
    end

    @tags_publishers = {}
    @publishers_media = {}

    @report.processed_csv.each do |row|
      tag_id = row[1]
      step_index = @report.steps.index{|r| r[0] == tag_id}

      tag_media_ids = MediaTag.where(tag_id: tag_id).pluck(:media_id)
      media = Media.in(id: tag_media_ids)
      media = media.gte(created_time: @report.date_from) if @report.date_from
      media = media.lte(created_time: @report.date_to) if @report.date_to

      media_ids = media.pluck_to_hash(:id, :user_id)#.uniq{ |r| r[:user_id] }
      publishers_ids = media_ids.map{ |m| m[:user_id] }
      @tags_publishers[tag_id] = publishers_ids

      @publishers_media[tag_id] = {}
      media_ids.each do |r|
        @publishers_media[tag_id][r[:user_id]] ||= []
        @publishers_media[tag_id][r[:user_id]] << r[:id]
      end

      unless @report.steps[step_index][1].include?('media_actual')
        media_for_update = []
        media_ids.select{ |m| m[:id] }.in_groups_of(10_000, false) do |ids|
          media_for_update.concat Media.in(id: ids).or(image: nil).pluck(:id)
        end

        if media_for_update.size == 0
          @report.steps[step_index][1] << 'media_actual'
        else
          media_for_update.each { |mid| MediaUpdateWorker.perform_async mid }
        end
      end

      unless @report.steps[step_index][1].include?('publishers_info')
        users = []
        publishers_ids.in_groups_of(5_000, false) do |ids|
          users.concat User.in(id: ids).outdated.pluck(:id)
        end
        if users.size == 0
          @report.steps[step_index][1] << 'publishers_info'
        else
          users.each { |uid| UserWorker.perform_async uid }
        end
      end

      if @report.steps[step_index][1].include?('publishers_info')
        if @report.output_data.include?('likes') && !@report.steps[step_index][1].include?('likes')
          get_likes = User.in(id: publishers_ids).without_likes.with_media.not_private.pluck(:id)
          if get_likes.size == 0
            @report.steps[step_index][1] << 'likes'
          else
            get_likes.each { |uid| UserAvgLikesWorker.perform_async uid }
          end
        end

        if @report.output_data.include?('location') && !@report.steps[step_index][1].include?('location')
          get_location = User.in(id: publishers_ids).without_location.with_media.not_private.pluck(:id)
          if get_location.size == 0
            @report.steps[step_index][1] << 'location'
          else
            get_location.each { |uid| UserLocationWorker.perform_async uid }
          end
        end

        if @report.output_data.include?('feedly') && !@report.steps[step_index][1].include?('feedly')
          with_website = []
          feedly_exists = []
          @report.processed_ids.in_groups_of(5_000, false) do |ids|
            for_process = User.in(id: ids).with_url.pluck(:id)
            with_website.concat for_process
            feedly_exists.concat Feedly.in(user_id: for_process).pluck(:user_id)
          end

          no_feedly = with_website - feedly_exists

          if no_feedly.size == 0
            @report.steps << 'feedly'
          else
            no_feedly.each { |uid| UserFeedlyWorker.new.perform uid }
            @progress += feedly_exists.size / with_website.size.to_f / @parts_amount
          end
        end
      end
    end

    @progress += ((@report.steps.inject(0) { |sum, tag_data| sum + tag_data[1].size}.to_f / (@report.processed_csv.size*@parts_amount)).round(2) * 100).to_i
    @report.progress = @progress

    if @report.progress == 100
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
    header += ['Media Link', 'Media Likes', 'Media Comments', 'Media Date']
    header += ['Media Image'] if @report.output_data.include? 'media_url'

    @report.processed_csv.each do |row|
      tag_id = row[1]
      tag = Tag.find(tag_id)

      media_list = {}
      @publishers_media[tag_id].values.flatten.in_groups_of(10_000, false) do |rows|
        Media.in(id: rows).pluck_to_hash(:user_id, :likes_amount, :comments_amount, :link, :image, :created_time).each do |media_row|
          media_list[media_row[:user_id]] ||= []
          media_list[media_row[:user_id]] << media_row
        end
      end

      csv_string = CSV.generate do |csv|
        csv << header
        @tags_publishers[tag_id].in_groups_of(1000, false) do |ids|
          User.in(id: ids).each do |u|
            users_media = media_list[u.id]
            next unless users_media
            unless @report.output_data.include? 'all_media'
              users_media = [users_media.last]
            end
            users_media.each do |media|
              row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
              row += [u.location_country, u.location_state, u.location_city] if @report.output_data.include? 'location'
              row += [u.avg_likes] if @report.output_data.include? 'likes'
              if @report.output_data.include? 'feedly'
                feedly = u.feedly.first
                row += [feedly ? feedly.subscribers_amount : '']
              end
              row += [media[:link], media[:likes_amount], media[:comments_amount], media[:created_time].strftime('%m/%d/%Y %H:%M:%S')]
              row += [media[:image]] if @report.output_data.include? 'media_url'

              csv << row
            end
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

      filepath = "reports/tag-#{@report.processed_csv.size}-publishers-#{Time.now.to_i}.zip"
      FileManager.save_file filepath, content: binary_data
      @report.result_data = filepath
    end

    @report.finished_at = Time.now
    @report.save

    ReportMailer.users(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end
end