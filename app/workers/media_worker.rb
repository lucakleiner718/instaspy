class MediaWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] },
    queue: :middle, unique_job_expiration: 3*60*60

  def perform tag_id, *args
    tag = Tag.find(tag_id)
    tag.observed_tag.update_attribute :media_updated_at, Time.now if tag.observed_tag
    tag.recent_media *args
  end

  def self.spawn
    tags = Tag.where(id: ObservedTag.where("media_updated_at < ? OR media_updated_at is null", 5.minute.ago).pluck(:tag_id)).order('observed_tags.media_updated_at asc')
    tags.each do |tag|
      MediaWorker.perform_async tag.id
    end
  end
end
