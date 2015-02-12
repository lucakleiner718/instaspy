class MediaLocationWorker
  include Sidekiq::Worker

  def perform media_id
    media = Media.find media_id
    media.update_location! if media && media.location_present? && media.location_lat.present?
  end
end