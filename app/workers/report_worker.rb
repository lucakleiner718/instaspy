class ReportWorker
  include Sidekiq::Worker

  def perform
    Reporter.media_report
  end
end