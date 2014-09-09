class MediaWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false, backtrace: true, unique: true

  def perform
    Media.recent_media
  end
end