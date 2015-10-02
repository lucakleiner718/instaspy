class Report::Tags < Report::Base

  def reports_new
    processed_input = @report.original_csv.map(&:first).map(&:downcase)

    # catch all exists tags
    tags = Tag.where(name: processed_input).pluck(:name, :id)

    # check if input contains tags we don't have in database
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
    @parts_amount = 1
    ['likes', 'location', 'feedly'].each do |info|
      @parts_amount += 1 if @report.output_data.include?(info)
    end

    @tags_publishers = {}
    @publishers_media = {}

    @report.processed_csv.each do |row|
      tag_id = row[1]
      step_index = @report.steps.index{|r| r[0] == tag_id}

      @publishers_media[tag_id] = {}

      media_items_key = "tag_#{tag_id}_media_items_file"
      if @report.data[media_items_key].present?
        csv = CSV.parse FileManager.read_file(@report.data[media_items_key])
        keys = csv.shift
        @media_items = csv.map{|el| obj = {}; keys.each_with_index{|key, index| obj[key.to_sym] = el[index]}; obj}

        @media_items.each do |r|
          @publishers_media[tag_id][r[:user_id].to_i] ||= []
          @publishers_media[tag_id][r[:user_id].to_i] << r
        end
      else
        # res = Media.connection.execute(
        #   "
        #    SELECT media.id, media.user_id, media.likes_amount, media.comments_amount, media.link, media.image, media.created_time
        #    FROM media
        #    LEFT JOIN (
        #      SELECT id, media.user_id
        #      FROM media
        #      WHERE media.id IN (
        #        select media_id
        #        from media_tags
        #        where tag_id=#{tag_id}
        #      )
        #      #{"AND created_time >= '#{@report.date_from.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')}'" if @report.date_from}
        #      #{"AND created_time =< '#{@report.date_to.end_of_day.strftime('%Y-%m-%d %H:%M:%S')}'" if @report.date_to}
        #      GROUP BY user_id, id
        #    ) as media_tmp ON media_tmp.id = media.id
        #   "
        # ).to_a

        tag_media_ids = MediaTag.where(tag_id: tag_id).pluck(:media_id)
        @media_items = []
        tag_media_ids.in_groups_of(100_000, false) do |ids|
          media = Media.where(id: ids)
          media = media.where("created_time >= ?", @report.date_from.beginning_of_day) if @report.date_from
          media = media.where("created_time <= ?", @report.date_to.end_of_day) if @report.date_to

          @media_items += media.pluck_to_hash(:id, :user_id, :likes_amount, :comments_amount, :link, :image, :created_time)
        end

        @media_items.each do |r|
          @publishers_media[tag_id][r[:user_id]] ||= []
          @publishers_media[tag_id][r[:user_id]] << r
        end

        unless @report.output_data.include? 'all_media'
          @publishers_media[tag_id] = @publishers_media[tag_id].inject({}){|obj, (user_id, media)| obj[user_id] = [media.sort{|a,b| a[:created_time] <=> b[:created_time]}.last]; obj}
          @media_items = @publishers_media[tag_id].values.flatten
        end

        if @media_items.size > 0
          csv_string = CSV.generate do |csv|
            csv << @media_items.flatten.first.keys
            @media_items.each do |media|
              csv << media.values
            end
          end
        else
          csv_string = ''
        end

        filepath = "reports/reports_data/report-#{@report.id}-tag-#{tag_id}-media-items.csv"
        FileManager.save_file filepath, content: csv_string
        @report.data[media_items_key] = filepath

        @report.save
      end

      publishers_ids = @publishers_media[tag_id].keys
      @tags_publishers[tag_id] = publishers_ids

      unless @report.steps[step_index][1].include?('publishers_info')
        users = []
        publishers_ids.in_groups_of(50_000, false) do |ids|
          users.concat User.where(id: ids).outdated(7.days.ago(@report.created_at)).pluck(:id)
        end
        if users.size == 0
          @report.steps[step_index][1] << 'publishers_info'
          @report.save
        else
          users.each { |uid| UserUpdateWorker.perform_async uid }
        end
      end

      if @report.steps[step_index][1].include?('publishers_info')
        if @report.output_data.include?('likes') && !@report.steps[step_index][1].include?('likes')
          get_likes = User.where(id: publishers_ids).without_likes.with_media.not_private.pluck(:id)
          if get_likes.size == 0
            @report.steps[step_index][1] << 'likes'
            @report.save
          else
            get_likes.each { |uid| UserAvgDataWorker.perform_async uid }
          end
        end

        if @report.output_data.include?('location') && !@report.steps[step_index][1].include?('location')
          get_location = User.where(id: publishers_ids).without_location.with_media.not_private.pluck(:id)
          if get_location.size == 0
            @report.steps[step_index][1] << 'location'
            @report.save
          else
            get_location.each { |uid| UserLocationWorker.perform_async uid }
          end
        end

        if @report.output_data.include?('feedly') && !@report.steps[step_index][1].include?('feedly')
          with_website = []
          feedly_exists = []
          @report.processed_ids.in_groups_of(5_000, false) do |ids|
            for_process = User.where(id: ids).with_url.pluck(:id)
            with_website.concat for_process
            feedly_exists.concat Feedly.where(user_id: for_process).pluck(:user_id)
          end

          no_feedly = with_website - feedly_exists

          if no_feedly.size == 0
            @report.steps << 'feedly'
            @report.save
          else
            no_feedly.each { |uid| UserFeedlyWorker.new.perform uid }
            @progress += feedly_exists.size / with_website.size.to_f / @parts_amount
          end
        end
      end
    end

    @progress += ((@report.steps.inject(0) { |sum, tag_data| sum + tag_data[1].size}.to_f / (@report.processed_csv.size*@parts_amount)).round(2) * 100).to_i
    @report.progress = @progress

    @report.save

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
    header += ['Relation']

    @report.processed_csv.each do |row|
      tag_id = row[1]
      tag = Tag.find(tag_id)

      next unless @tags_publishers[tag_id]

      csv_string = CSV.generate do |csv|
        csv << header

        @tags_publishers[tag_id].in_groups_of(50_000, false) do |ids|
          User.where(id: ids).each do |u|
            users_media = @publishers_media[tag_id][u.id]
            next unless users_media
            users_media.each do |media|
              row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
              row += [u.location_country, u.location_state, u.location_city] if @report.output_data.include? 'location'
              row += [u.avg_likes] if @report.output_data.include? 'likes'
              if @report.output_data.include? 'feedly'
                feedly = u.feedly.first
                row += [feedly ? feedly.subscribers_amount : '']
              end

              row += [media[:link], media[:likes_amount], media[:comments_amount], (media[:created_time].is_a?(String) ? DateTime.parse(media[:created_time]) : media[:created_time]).strftime('%m/%d/%Y %H:%M:%S')]
              row += [media[:image]] if @report.output_data.include? 'media_url'

              row << tag.name

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

    ReportMailer.tags(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end
end
