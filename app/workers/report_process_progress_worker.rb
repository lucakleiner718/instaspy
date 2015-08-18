class ReportProcessProgressWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, queue: :critical

  def perform report_id
    report = Report.where(status: :in_process, id: report_id).first

    return unless report

    if report.format.in?(Report::GOALS.map(&:last))
      klass = "Report::#{report.format.titleize.gsub(/\s/, '')}".constantize
      rep = klass.new(report)
      rep.reports_in_process
    end
  end

  def self.spawn
    Report.where(status: :in_process).order(created_at: :asc).limit(ENV['ACTIVE_REPORTS_AMOUNT'] || 1).each do |report|
      self.perform_async report.id.to_s
    end
  end
end