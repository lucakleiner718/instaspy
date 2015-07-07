class TagStatWorker

  include Sidekiq::Worker

  sidekiq_options unqiue: true,
                  unique_args: -> (args) { [ args.first ] }

  def perform tag_id, beginning=1.day
    tag = Tag.find(tag_id)
    start = beginning.ago.utc.beginning_of_day
    finish = start.utc.end_of_day

    return false if TagStat.where(tag: tag, date: start).size > 0

    media = tag.media.where("created_time >= ?", start).where("created_time <= ?", finish)
    TagStat.create tag: tag, amount: media.size, date: start
  end

  def self.spawn beginning=1.day
    Tag.chartable.each do |tag|
      self.perform_async(tag.id, beginning)
      # self.new.perform(tag.id, beginning)
    end
  end

end
