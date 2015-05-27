class ReportProcessNewWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, queue: :critical

  def perform report_id
    report = Report.where(status: :new, id: report_id).first

    return if !report || Report.where(status: :in_process).size > 0

    case report.format
      when 'followers'
        rep = Report::Followers.new(report)
      when 'followees'
        rep = Report::Followees.new(report)
      when 'users'
        rep = Report::Users.new(report)
      when 'tags'
        rep = Report::Tags.new(report)
      when 'recent-media'
        rep = Report::RecentMedia.new(report)
      else
        rep = nil
    end

    rep.reports_new if rep
  end

  def self.spawn
    report = Report.where(status: :new).order(created_at: :asc).first
    self.perform_async report.id.to_s if report
  end
end