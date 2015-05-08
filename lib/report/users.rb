class Report::Users < Report::Base

  def reports_new
    self.process_users_input

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

    self.process_user_info

    if @report.steps.include?('user_info')
      self.process_likes @report.processed_ids
      self.process_location @report.processed_ids
      self.process_feedly @report.processed_ids
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

    binding.pry

    csv_string = CSV.generate do |csv|
      csv << header
      User.in(id: @report.processed_ids).each do |u|
        row = [u.insta_id, u.username, u.full_name, u.website, u.bio, u.follows, u.followed_by, u.email]
        row.concat [u.location_country, u.location_state, u.location_city] if @report.output_data.include? 'location'
        row.concat [u.avg_likes] if @report.output_data.include? 'likes'
        if @report.output_data.include? 'feedly'
          feedly = u.feedly.first
          row.concat [feedly ? feedly.subscribers_amount : '']
        end

        csv << row
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
  end
end