class TagChartWorker
  # include Sidekiq::Worker

  def perform tag_id, amount_of_days=Tag::CHART_DAYS
    tag = Tag.where('id = :tag_id OR name = :tag_id', tag_id: tag_id).first
    values = tag.chart_data amount_of_days
    Rails.cache.write("chart-#{tag.name}", values, expires_in: 6.hours)
    values
  end

  def self.spawn
    Tag.chartable.each do |tag|
      self.new.perform tag.id
    end
  end

end