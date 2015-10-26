class MediaWorker
  include Sidekiq::Worker

  sidekiq_options queue: :middle, unique: true, unique_args: -> (args) { [ args.first ] }

  def perform tag_id, *args
    tag = Tag.find(tag_id)
    tag.observed_tag.update_attribute :media_updated_at, Time.now if tag.observed_tag
    tag.recent_media *args
  end

  def self.spawn
    tags = Tag.joins(:observed_tag).where("media_updated_at < ? OR media_updated_at is null", 5.minute.ago).order('media_updated_at')
    tags.each do |tag|
      MediaWorker.perform_async tag.id
    end
  end
end
