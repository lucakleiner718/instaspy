class Report::RecentMedia < Report::Base

  def reports_in_process
    @parts_amount = 2

    self.process_user_info

    if @report.steps.include?('user_info')
      unless @report.steps.include?('recent_media')
        not_processed = @report.processed_ids - @report.tmp_list1
        if not_processed.size == 0
          @report.steps << 'recent_media'
        else
          not_processed.each do |uid|
            ReportRecentMediaWorker.perform_async uid, @report.id
          end

          @progress += not_processed.size / @report.processed_ids.size.to_f / @parts_amount
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

    users_media = {}

    @report.processed_ids.in_groups_of(1000, false) do |uids|
      Media.in(user_id: uids).order_by(created_time: :desc).pluck(:id, :user_id).each do |row|
        users_media[row[1]] = [] unless users_media[row[1]]
        users_media[row[1]] << row[0]
      end
    end

    header = ['ID', 'Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followers', 'Email', 'Media Link', 'Media Likes', 'Media Comments', 'Media Published', 'Media Tags']

    csv_string = CSV.generate do |csv|
      csv << header
      User.in(id: @report.processed_ids).each do |u|
        next unless users_media[u.id]

        media_ids = users_media[u.id][0,20]
        tags_ids = MediaTag.in(media_id: media_ids.join(',')).pluck(:tag_id, :media_id)
        tags_all = Tag.in(id: tags_ids.map{|r| r[0]}.uniq).pluck(:id, :name)
        Media.in(id: media_ids).order_by(created_time: :desc).pluck(:link, :likes_amount, :comments_amount, :created_time, :id).each do |media|
          tags = tags_ids.select{|r| r[1] == media[4]}.map{|r| r[0]}
          row = [
            u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email,
            media[0], media[1], media[2], media[3].strftime('%m/%d/%Y %H:%M:%S'), tags_all.select{|r| r[0].in?(tags)}.map(&:last).join(',')
          ]
          csv << row
        end
      end
    end

    basename = "users-#{@report.processed_ids.size}-report-#{Time.now.to_i}"

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
      @report.result_data = filepath
    end

    @report.finished_at = Time.now
    @report.save

    ReportMailer.users(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end
end