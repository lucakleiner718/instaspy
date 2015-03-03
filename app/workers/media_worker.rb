class MediaWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] },
    queue: :middle, unique_job_expiration: 6*60*60

  def perform tag_id
    tag = Tag.find(tag_id)
    tag.observed_tag.update_column :media_updated_at, Time.now
    tag.recent_media
  end

  def self.spawn
    tags = Tag.observed.where('observed_tags.media_updated_at < ? or observed_tags.media_updated_at is null', 5.minute.ago).order('observed_tags.media_updated_at asc')
    tags.each do |tag|
      MediaWorker.perform_async tag.id
    end
  end
end