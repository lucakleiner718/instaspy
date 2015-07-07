class DailyMediaStatWorker
  include Sidekiq::Worker

  def perform date
    date = DateTime.parse(date) if date.class.name == 'String'
    start = date.utc.beginning_of_day
    finish = start.end_of_day

    amount = Media.where("created_time >= ?", start).where("created_time <= ?", finish).size
    mas = MediaAmountStat.where(date: start.to_date, action: 'published').first_or_initialize
    mas.amount = amount
    mas.save

    amount = Media.where("created_at >= ?", start).where("created_at <= ?", finish).size
    mas = MediaAmountStat.where(date: start.to_date, action: 'added').first_or_initialize
    mas.amount = amount
    mas.save
  end

  def self.spawn
    first = Time.now.utc.beginning_of_day
    (0..14).each do |i|
      day = i.days.ago(first)
      # DailyMediaStatWorker.new.perform day
      DailyMediaStatWorker.perform_async day
    end
  end
end
