class ReportProcessNewWorker
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed, queue: :critical

  def perform report_id
    report = Report.where(status: :new, id: report_id).first

    return if !report || Report.where(status: :in_process).size > (ENV['ACTIVE_REPORTS_AMOUNT'] || 1).to_i-1

    if report.format.in?(Report::GOALS.map(&:last))
      klass = "Report::#{report.format.titleize.gsub(/\s/, '')}".constantize rescue false
      if klass
        rep = klass.new(report)
        rep.reports_new
      end
    end
  end

  def self.spawn
    report = Report.where(status: :new).order(created_at: :asc).first
    self.perform_async report.id.to_s if report
  end
end