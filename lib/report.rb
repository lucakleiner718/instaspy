class Report

  def self.invalidate_batches
    Sidekiq::BatchSet.new.each do |status|
      Sidekiq::Batch.new(status.bid).invalidate_all rescue nil
      Sidekiq::Batch.new(status.bid).status.delete rescue nil
    end
    ReportProcessNewWorker.spawn
    ReportProcessProgressWorker.spawn
  end

end