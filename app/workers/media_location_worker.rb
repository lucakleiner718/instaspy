class MediaLocationWorker

  include Sidekiq::Worker
  sidekiq_options unique: :until_and_while_executing

  def perform media_id
    media = Media.find media_id
    media.update_location! if media && media.location_present? && media.location_lat.present?
  end

end