class SidekiqBatchesCleanWorker
  include Sidekiq::Worker
  sidekiq_options queue: :low

  def perform
    Sidekiq::BatchSet.new.each do |status|
      if status.pending < 0
        Sidekiq::Batch.new(status.bid).invalidate_all rescue nil
        status.delete rescue nil
      end
    end
  end
end