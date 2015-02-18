class ReportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical, retry: true, backtrace: true

  def perform
    Reporter.media_report
  end
end