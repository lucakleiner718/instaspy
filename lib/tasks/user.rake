namespace :user do
  desc 'Update followers of shopbop'
  task :followers => :environment do
    user = User.add_by_username ENV['name']
    Daemons.daemonize
    user.update_followers ignore_exists: true
  end
end
