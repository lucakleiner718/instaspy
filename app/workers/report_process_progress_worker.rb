class ReportProcessProgressWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform report_id
    report = Report.where(status: :in_process, id: report_id).first

    return unless report

    if report.format == 'followers'
      Report::Followers.reports_in_process report
    end
  end

  def self.spawn
    Report.where(status: :in_process).each do |report|
      self.perform_async report.id.to_s
    end
  end
end