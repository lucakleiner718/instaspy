class TagCompleteMediaWorker
  include Sidekiq::Worker

  def perform tag_id, offset=nil, created_from=nil, total_limit=nil
    tag = Tag.find tag_id
    tag.recent_media offset: offset, created_from: created_from, total_limit: total_limit
  end

  def self.spawn tag_id
    30.times do |i|
      TagCompleteMediaWorker.perform_async tag_id, (i.days.ago if i > 0), (i+1).days.ago, total_limit: 50_000
    end
  end
end