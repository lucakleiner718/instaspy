class TagsToMediaWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform media_id, tags_ids
    Media.connection.execute("INSERT IGNORE INTO media_tags (media_id, tag_id) VALUES #{tags_ids.map{|tid| "(#{media_id}, #{tid})"}.join(',')}")
  end
end