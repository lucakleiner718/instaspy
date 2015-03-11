class FollowersReportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical, retry: true, backtrace: true

  def perform
    FollowersReport.send_weekly_report
  end
end