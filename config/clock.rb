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

  # Grab new media for observed tags
  # every(10.seconds, 'get.new.media') { Media.recent_media }
  # every(1.minute, 'get.new.media') { MediaWorker.spawn }

  # Update users, which doesn't have info
  every(10.minutes, 'update.users') { UserWorker.perform_async }

  # Send weekly report about media
  every(1.week, 'media.report', at: "Tuesday 07:00") { ReportWorker.perform_async }

  # Delete old media records
  every(1.day, 'media.delete_old', at: '08:00') { Media.delete_old }

  # Save data for chart in cache, so charts will work fast
  every(3.hours, 'TagChartWorker') { TagChartWorker.spawn }

  # Update followers list for specified users
  every(12.hours, 'FollowersReport.update') { FollowersReport.track }

  # Send weekly report about followers for specified users
  every(1.week, 'FollowersReport.report', at: "Thursday 04:00") { FollowersReport.send_weekly_report }

  # Save some stat
  every(1.day, 'StatWorker', at: '00:00') { StatWorker.perform_async }

  # Save tag stat for chart
  every(1.day, 'TagStat', at: '01:00') { TagStatWorker.spawn }

end