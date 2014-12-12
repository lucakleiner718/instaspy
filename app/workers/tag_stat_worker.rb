class TagStatWorker

  include Sidekiq::Worker

  sidekiq_options unqiue: true,
                  unique_args: -> (args) { [ args.first ] }

  def perform tag_id
    tag = Tag.find(tag_id)
    start = 1.day.ago.utc.beginning_of_day
    finish = start.utc.end_of_day

    return false if TagStat.where(tag: tag, date: start).size > 0

    media = tag.media.where('created_time >= :start and created_time <= :finish', start: start, finish: finish)
    TagStat.create tag: tag, amount: media.size, date: start
  end

  def self.spawn
    Tag.chartable.each do |tag|
      # self.perform_async(tag.id)
      self.new.perform(tag.id)
    end
  end

end