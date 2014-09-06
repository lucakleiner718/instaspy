# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

every 5.minutes do
  runner 'MediaWorker.perform_async'
end

every 10.minutes do
  runner 'UserWorker.perform_async'
end

every :tuesday, at: '4am' do
  runner 'ReportWorker.perform_async'
end

# media_grabber:
#   cron: "*/1 * * * *"
#   class: MediaWorker
#
# user_grabber:
#   cron: "*/10 * * * *"
#   class: UserWorker
#
# report_weekly:
#   cron: "4 0 * * 2"
#   class: ReportWorker