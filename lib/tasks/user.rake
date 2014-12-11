namespace :user do
  desc 'Update followers of SOMENAME'
  task :followers => :environment do
    user = User.add_by_username ENV['name']
    Daemons.daemonize
    user.update_followers ignore_exists: true
  end

  desc 'Update followees of SOMENAME'
  task :followees => :environment do
    usernames = ENV['name'].split(',')

    Daemons.daemonize

    usernames.each do |username|
      user = User.add_by_username username
      user.update_followees ignore_exists: true
    end
  end
end
