class TagChartWorker
  include Sidekiq::Worker

  def perform tag_id, amount_of_days=Tag::CHART_DAYS
    tag = Tag.where('id = :tag_id OR name = :tag_id', tag_id: tag_id).first
    values = tag.chart_data amount_of_days
    Rails.cache.write("chart-#{tag.name}", values, expires_in: 6.hours)

    last_30_days = TagStat.where('date >= ?', 30.days.ago).where(tag: tag).pluck(:amount).sum
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