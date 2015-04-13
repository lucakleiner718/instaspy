class ReportProcessNewWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform report_id
    report = Report.where(status: :new).where(id: report_id).first

    return false unless report

    if report.format == 'followers'
      ids = []
      csv_data = report.input_csv
      csv_data.map! do |row|
        user = User.get(row[0])
        if user
          [row[0], user.username, user.id]
        else
          row
        end
      end

      csv_string = CSV.generate do |csv|
        csv_data.each do |row|
          csv << row
        end
      end
      File.write(Rails.root.join("public/reports_data/report-#{report.id}.csv"), csv_string)

      csv_data.select{|r| r[1].present?}.each do |row|
        user = User.find(row[2])
        ids << UserFollowersWorker.perform_async(user.id, ignore_exists: true)
      end

      report.status = :in_process
      report.jobs = ids.join(',')
      report.started_at = Time.now
      report.save
    end
  end

  def self.spawn
    Report.where(status: :new).each do |report|
      self.perform_async report.id
    end
  end
end