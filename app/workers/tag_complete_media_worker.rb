class TagCompleteMediaWorker

  include Sidekiq::Worker
  sidekiq_options queue: :low, unique: :until_executed,
      unique_args: -> (args) { [ args.first ] }

  def perform tag_id, *args
    options = args.extract_options!
    tag = Tag.find tag_id
    tag.recent_media offset: options[:offset], created_from: options[:created_from], total_limit: options[:total_limit], ignore_exists: true
  end

  def self.spawn tag_id, days: 30
    hours = days*24
    hours.times do |i|
      TagCompleteMediaWorker.perform_async tag_id, offset: (i.hours.ago if i > 0), created_from: (i+1).hours.ago, total_limit: 1_000_000
    end
  end

end