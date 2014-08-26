class MediaWorker
  include Sidekiq::Worker

  # sidekiq_options queue: "media"

  def perform
    Media.recent_media
  end
end