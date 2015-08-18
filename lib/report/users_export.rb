class Report::UsersExport < Report::Base

  def reports_new

    @report.amounts['found_users'] = scope.size
    @report.data['parts'] = []

    @report.status = :in_process
    @report.started_at = Time.now
    @report.save

    ReportProcessProgressWorker.perform_async @report.id
  end

  def reports_in_process
    range = 100_000
    parts_size = (@report.amounts['found_users'] / range.to_f).ceil
    (parts_size - @report.data['parts'].size).times do |i|
      i += @report.data['parts'].size
      users = scope.offset(range * i).limit(range)

      csv_string = Reporter.users_export ids: users.pluck(:id), return_csv: true, additional_columns: [:location]
      filepath = "reports/reports_data/report-#{@report.id}-users-export-#{i}-#{users.size}-#{Time.now.to_i}.csv"
      filepath_full = Rails.root.join('tmp', filepath)
      FileUtils.mkdir_p File.dirname(filepath_full)
      File.write filepath_full, csv_string
      @report.data['parts'] << filepath.to_s
      @report.save
    end

    @report.progress = 100
    @report.save

    finish

    @report.save
  end

  def finish
    if @report.data['parts'].size > 0
      zipfile_name = Rails.root.join('tmp', "reports/reports_data/report-#{@report.id}-archive.zip")

      Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
        @report.data['parts'].each do |filename|
          filepath_full = Rails.root.join('tmp', filename)
          zipfile.add(File.basename(filepath_full), filepath_full)
        end
        # zipfile.get_output_stream("myFile") { |os| os.write "myFile contains just this" }
      end

      filepath = "reports/reports_data/report-#{@report.id}-archive.zip"
      FileManager.save_file filepath, file: zipfile_name
      @report.result_data = filepath
    end

    @report.status = :finished
    @report.finished_at = Time.now
    @report.save

    ReportMailer.users_export(@report.id).deliver if @report.notify_email.present?

    self.after_finish
  end

  def scope
    users = User.all
    users = users.where('LOWER(location_country) = LOWER(?)', @report.data['country']) if @report.data['country'].present?
    users = users.where('LOWER(location_state) = LOWER(?)', @report.data['state']) if @report.data['state'].present?
    users = users.where('LOWER(location_city) = LOWER(?)', @report.data['city']) if @report.data['city'].present?
    users
  end

end