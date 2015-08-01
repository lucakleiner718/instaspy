class TagCompleteMediaWorker
  include Sidekiq::Worker

  sidekiq_options queue: :low, unique_args: -> (args) { [ args.first ] }

  def perform tag_id, *args
    options = args.extract_options!
    tag = Tag.find tag_id
    tag.recent_media offset: options[:offset], created_from: options[:created_from], total_limit: options[:total_limit], ignore_exists: true
  end

  def self.spawn tag_id, days: 30
    days.times do |i|
      TagCompleteMediaWorker.perform_async tag_id, offset: (i.days.ago if i > 0), created_from: (i+1).days.ago, total_limit: 1_000_000
    end
  end
end