class ReportWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical

  def perform
    Reporter.media_report
  end
end