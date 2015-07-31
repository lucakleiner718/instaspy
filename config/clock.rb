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
  every(15.minute, 'get.new.media') { MediaWorker.spawn }

  every(1.day, 'check.media', if: lambda { |t| t.day == 1 }) {
    Tag.observed.pluck(:id).each do |tag_id|
      TagCompleteMediaWorker.spawn tag_id
    end
  }

  # Update users, which doesn't have info
  every(30.minutes, 'update.users') { UserWorker.spawn }

  # Save data for chart in cache, so charts will work fast
  every(6.hours, 'TagChartWorker') { TagChartWorker.spawn }

  # Update followers list for specified users
  every(12.hours, 'FollowersReport.update') { FollowersReport.track }

  # Save some stat
  every(1.day, 'StatWorker', at: '00:00') { StatWorker.perform_async }
  every(10.minutes, 'LimitsWorker') { LimitsWorker.perform_async }

  # Save tag stat for chart
  every(1.day, 'TagStat', at: '01:00') { TagStatWorker.spawn }

  every(12.hours, 'media.amount.stat') {
    DailyMediaStatWorker.spawn
  }

  every(5.minutes, 'ReportProcessNewWorker') {
    ReportProcessNewWorker.spawn
  }

  every(5.minutes, 'ReportProcessProgressWorker') {
    ReportProcessProgressWorker.spawn
  }

  every(5.minutes, 'ImportUsersWorker') {
    ImportUsersWorker.spawn
  }

  # Weekly Reports

  # Send weekly report about followers for specified users
  every(1.week, 'FollowersReport.report', at: "Wednesday 02:00") { FollowersReportWorker.perform_async }

  # Send weekly report about media
  every(1.week, 'media.report', at: "Wednesday 03:00") { ReportWorker.perform_async }

end