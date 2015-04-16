class ReportProcessNewWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform report_id
    report = Report.where(status: :new, id: report_id).first

    return unless report

    case report.format
      when 'followers'
        Report::Followers.reports_new report
      when 'users'
        Report::Users.reports_new report
    end
  end

  def self.spawn
    Report.where(status: :new).each do |report|
      self.perform_async report.id.to_s
    end
  end
end