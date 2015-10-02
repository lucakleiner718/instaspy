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

  if ENV['REGULAR_JOBS']
    # Grab new media for observed tags
    every(15.minute, 'get.new.media') { MediaWorker.spawn }

    # every(1.day, 'check.media', if: lambda { |t| t.day == 1 }) {
    #   Tag.observed.pluck(:id).each do |tag_id|
    #     TagCompleteMediaWorker.spawn tag_id
    #   end
    # }

    # Save data for chart in cache, so charts will work fast
    every(6.hours, 'TagChartWorker') { TagChartWorker.spawn }

    # Update followers list for specified users
    every(12.hours, 'FollowersReport.update') do
      TrackUser.where(followers: true).pluck(:user_id).each do |user_id|
        UserFollowersCollectWorker.perform_async user_id
      end
    end

    # Save tag stat for chart
    every(1.day, 'TagStat', at: '01:00') { TagStatWorker.spawn }

    # Update stat data for media chart
    every(1.day, 'media.amount.stat', at: '04:00') { DailyMediaStatWorker.spawn }

    # Weekly Reports
    # Send weekly report about followers for specified users
    every(1.week, 'FollowersReport.report', at: "Wednesday 02:00") { RegularReports.followers_weekly }
    # Send weekly report about media
    every(1.week, 'media.report', at: "Wednesday 03:00") { RegularReports.publishers_weekly }
    # Weekly Reports END
  end

  # Update some stat
  every(1.day, 'StatWorker', at: '00:00') { StatWorker.perform_async }
  every(10.minutes, 'LimitsWorker') { LimitsWorker.perform_async }

  # Process reports
  every(5.minutes, 'ReportProcess') {
    ReportProcessNewWorker.spawn
    ReportProcessProgressWorker.spawn
  }

end