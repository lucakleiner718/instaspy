class FollowersReportWorker
  include Sidekiq::Worker

  def perform
    FollowersReport.send_weekly_report
  end
end