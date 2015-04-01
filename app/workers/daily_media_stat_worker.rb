class DailyMediaStatWorker
  include Sidekiq::Worker

  def perform date
    start = date.utc.beginning_of_day
    finish = start.end_of_day

    amount = Media.where('created_time >= ? AND created_time <= ?', start, finish).size
    mas = MediaAmountStat.where(date: start.to_date, action: 'published').first_or_initialize
    mas.amount = amount
    mas.save

    amount = Media.where('created_at >= ? AND created_at <= ?', start, finish).size
    mas = MediaAmountStat.where(date: start.to_date, action: 'added').first_or_initialize
    mas.amount = amount
    mas.save
  end

  def self.spawn
    first = Time.now.utc.beginning_of_day
    (0..14).each do |i|
      day = i.days.ago(first)
      # self.perform_async day
      self.new.perform day
    end
  end
end