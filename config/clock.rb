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
  # every(1.minute, 'get.new.media') { MediaWorker.spawn }

  every(1.month, 'check.media', at: '00:00') {
    tags = Tag.observed
    tags.each do |tag|
      tag.delay.recent_media created_from: 1.month.ago
    end
  }

  # Update users, which doesn't have info
  every(20.minutes, 'update.users') { UserWorker.spawn }

  # Send weekly report about media
  every(1.week, 'media.report', at: "Tuesday 07:00") { ReportWorker.perform_async }

  # Delete old media records
  # every(1.week, 'media.delete_old', at: '08:00') { Media.delete_old }

  # Save data for chart in cache, so charts will work fast
  every(6.hours, 'TagChartWorker') { TagChartWorker.spawn }

  # Update followers list for specified users
  every(12.hours, 'FollowersReport.update') { FollowersReport.track }

  # Send weekly report about followers for specified users
  every(1.week, 'FollowersReport.report', at: "Thursday 04:00") { FollowersReportWorker.perform_async }

  # Save some stat
  every(1.day, 'StatWorker', at: '00:00') { StatWorker.perform_async }

  # Save tag stat for chart
  every(1.day, 'TagStat', at: '01:00') { TagStatWorker.spawn }

  every(30.minutes, 'media.ny.location.1') {
    Media.get_by_location 40.74226964, -74.007271584 if Time.now < Time.at('2015/02/21 00:00:00 UTC')
  }
  every(30.minutes, 'media.ny.location.2') {
    Media.get_by_location 40.772154986, -73.984437991 if Time.now < Time.at('2015/02/21 00:00:00 UTC')
  }

  # every(30.minutes, 'tag.user.location') {
  #   TagUserLocationWorker.spawn
  # }

end