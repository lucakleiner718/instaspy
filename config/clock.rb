require 'clockwork'
require 'clockwork/database_events'
require_relative './boot'
require_relative './environment'

module Clockwork
  handler do |job, time|
    puts "Running #{job}, at #{time}"
  end

  configure do |config|
    config[:tz] = Time.zone
  end

  # every(1.minute, 'get.new.media') { MediaWorker.spawn }
  every(10.minutes, 'update.users') { UserWorker.perform_async }
  every(1.week, 'media.report', at: "Tuesday 16:00") { ReportWorker.perform_async }
  every(1.day, 'media.delete_old', at: '5:00') { Media.delete_old }
  every(3.hours, 'TagChartWorker') { TagChartWorker.spawn }
  every(12.hours, 'FollowersReport.shopbop') { FollowersReport.new('shopbop').get_new }
  every(1.week, 'FollowersReport.shopbop', at: "Thursday 4:00") { FollowersReport.new('shopbop').send_weekly_report }
  every(1.day, 'StatWorker', at: '0:00') { StatWorker.perform_async }

end