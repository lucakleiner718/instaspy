class ReportProcessNewWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] },
    queue: :critical

  def perform report_id
    report = Report.where(status: :new, id: report_id).first

    return unless report

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

    rep.reports_new report if rep
  end

  def self.spawn
    Report.where(status: :new).each do |report|
      self.perform_async report.id.to_s
    end
  end
end