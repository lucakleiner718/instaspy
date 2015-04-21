class UpdateTagMediaCounterWorker
  include Sidekiq::Worker

  sidekiq_options queue: :low, retry: 3

  def perform tid
    Media.connection.execute("UPDATE tags SET media_count=media_count+1 WHERE id=#{tid}")
  end
end