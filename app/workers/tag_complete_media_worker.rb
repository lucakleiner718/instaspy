class TagCompleteMediaWorker
  include Sidekiq::Worker

  def perform tag_id, offset: nil, created_from: nil, total_limit: nil
    tag = Tag.find tag_id
    tag.recent_media offset: offset, created_from: created_from, total_limit: total_limit
  end

  def self.spawn tag_id, days: 30
    days.times do |i|
      TagCompleteMediaWorker.perform_async tag_id, offset: (i.days.ago if i > 0), created_from: (i+1).days.ago, total_limit: 1_000_000
    end
  end
end