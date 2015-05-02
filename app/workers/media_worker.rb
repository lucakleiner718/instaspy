class MediaWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] },
    queue: :middle, unique_job_expiration: 3*60*60, retry: false

  def perform tag_id, *args
    tag = Tag.find(tag_id)
    tag.observed_tag.update_column :media_updated_at, Time.now if tag.observed_tag
    tag.recent_media *args
  end

  def self.spawn
    tags = Tag.where(:id.in => ObservedTag.or(:media_updated_at.lt => 5.minute.ago, media_updated_at: nil).pluck(:tag_id)).order('observed_tags.media_updated_at asc')
    tags.each do |tag|
      MediaWorker.perform_async tag.id
    end
  end
end