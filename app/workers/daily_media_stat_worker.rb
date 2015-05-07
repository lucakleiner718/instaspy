class DailyMediaStatWorker
  include Sidekiq::Worker

  def perform date
    start = date.utc.beginning_of_day
    finish = start.end_of_day

    amount = Media.gte(created_time: start).lte(created_time: finish).size
    mas = MediaAmountStat.where(date: start.to_date, action: 'published').first_or_initialize
    mas.amount = amount
    mas.save

    amount = Media.gte(created_at: start).lte(created_at: finish).size
    mas = MediaAmountStat.where(date: start.to_date, action: 'added').first_or_initialize
    mas.amount = amount
    mas.save
  end

  def self.spawn
    first = Time.now.utc.beginning_of_day
    (0..14).each do |i|
      day = i.days.ago(first)
      DailyMediaStatWorker.new.perform day
    end
  end
end