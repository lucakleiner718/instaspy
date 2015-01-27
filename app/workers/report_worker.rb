class ReportWorker
  include Sidekiq::Worker

  def perform
    Media.report
  end
end