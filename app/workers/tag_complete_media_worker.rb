class TagCompleteMediaWorker
  include Sidekiq::Worker

  def perform tag_id
    tag = Tag.find tag_id
    tag.recent_media created_from: 1.month.ago, total_limit: 50_000
  end
end