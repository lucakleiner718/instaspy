class Report::Callback
  def on_success status, options
    ReportProcessProgressWorker.perform_async options['report_id']
  end
end