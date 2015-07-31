class TagStatWorker

  include Sidekiq::Worker

  sidekiq_options unqiue: true,
                  unique_args: -> (args) { [ args.first ] }

  def perform tag_id, beginning=1.day, force=false
    tag = Tag.find(tag_id)
    start = beginning.to_i.seconds.ago.utc.beginning_of_day
    finish = start.utc.end_of_day

    return false if TagStat.where(tag: tag, date: start).size > 0 && !force

    media_size = tag.media.where("created_time >= ?", start).where("created_time <= ?", finish).size
    ts = TagStat.where(tag: tag, date: start).first_or_initialize
    ts.amount = media_size
    ts.save
  end

  def self.spawn beginning=1.day
    Tag.chartable.each do |tag|
      self.perform_async(tag.id, beginning)
    end
  end

end
