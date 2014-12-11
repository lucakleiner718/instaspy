class MediaWorker
  include Sidekiq::Worker

  def perform
    Media.recent_media
  end
end