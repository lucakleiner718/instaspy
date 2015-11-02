class Report::Callback

  attr_accessor :jid

  def on_success status, options
    ReportProcessProgressWorker.perform_async options['report_id']
  end

  def on_complete status, options
    if status.failures > 0
      Sidekiq::Batch.new(jid).invalidate_all
      Sidekiq::Batch.new(jid).status.delete
      ReportProcessProgressWorker.spawn
    end
  end
end