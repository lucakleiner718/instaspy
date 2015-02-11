class LocationWorker
  include Sidekiq::Worker

  def perform
    Media.with_location.where('location_country is null').each do |media|
      media.update_location!
    end
  end
end