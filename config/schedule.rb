every 1.minute do
  # runner 'MediaWorker.perform_async'
  runner 'Media.recent_media'
end

every 10.minutes do
  # runner 'UserWorker.perform_async'
  runner 'User.update_worker'
end

every :tuesday, at: '4am' do
  # runner 'ReportWorker.perform_async'
  runner 'Media.report'
end

every :day, at: '5am' do
  runner 'Media.delete_old'
end

# every 3.hours do
#   runner 'TagChartWorker.spawn'
# end

every 12.hours do
  runner "FollowersReport.new('shopbop').get_new"
end

every :thursday, at: '4am' do
  runner "FollowersReport.new('shopbop').send_weekly_report"
end