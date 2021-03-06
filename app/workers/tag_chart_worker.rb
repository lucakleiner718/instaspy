class TagChartWorker
  include Sidekiq::Worker

  sidekiq_options unique: :until_executed, unique_args: -> (args) { [ args.first ] }, unique_job_expiration: 3*60*60, retry: false

  def perform tag_id, amount_of_days=Tag::CHART_DAYS
    tag =
      if tag_id.class.name == 'Fixnum' || tag_id.numeric?
        Tag.find(tag_id)
      else
        Tag.where(name: tag_id).first
      end
    values = tag.chart_data amount_of_days
    Rails.cache.write("chart-#{tag.name}", values, expires_in: 6.hours)

    last_30_days = TagStat.where("date > ?", 30.days.ago).where(tag: tag).pluck(:amount).sum
    last_30_days = TagStat.order(date: :desc).first if last_30_days.blank?
    Rails.cache.write("tag-last-30-days-#{tag.name}", last_30_days, expires_in: 6.hours)

    values
  end

  def self.spawn
    Tag.chartable.each do |tag|
      self.perform_async tag.id
    end
  end

end
