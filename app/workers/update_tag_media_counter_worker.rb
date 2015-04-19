class UpdateTagMediaCounterWorker
  include Sidekiq::Worker

  sidekiq_options queue: :middle, retry: 3

  def perform media_id, tags_ids
    ActiveRecord::Base.transaction do
      Media.connection.execute("INSERT IGNORE INTO media_tags (media_id, tag_id) VALUES #{tags_ids.map{|tid| "(#{media_id}, #{tid})"}.join(',')}")
      Media.connection.execute("UPDATE tags SET media_count=media_count+1 WHERE id in (#{tags_ids.join(',')})")
    end
  end
end