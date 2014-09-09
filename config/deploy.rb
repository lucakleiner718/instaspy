# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, 'instaspy'
set :repo_url, 'git@github.com:luxagency/instaspy.git'

set :branch, :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call
set :scm, :git
set :format, :pretty
set :pty, false

set :log_level, :info #:debug

set :linked_files, %w{config/database.yml .env}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

set :keep_releases, 5

set :deploy_to, '/home/app/instaspy'


# set :puma_rackup, -> { File.join(current_path, 'config.ru') }
# set :puma_state, "#{shared_path}/tmp/pids/puma.state"
# set :puma_pid, "#{shared_path}/tmp/pids/puma.pid"
# set :puma_bind, "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_conf, "#{shared_path}/puma.rb"
# set :puma_access_log, "#{shared_path}/log/puma_error.log"
# set :puma_error_log, "#{shared_path}/log/puma_access.log"
# set :puma_role, :app
# set :puma_env, fetch(:rack_env, fetch(:rails_env, 'production'))
# set :puma_threads, [0, 16]
# set :puma_workers, 0
# set :puma_init_active_record, true
# set :puma_preload_app, true


# :sidekiq_default_hooks =>  true
# :sidekiq_pid =>  File.join(shared_path, 'tmp', 'pids', 'sidekiq.pid')
# :sidekiq_env =>  fetch(:rack_env, fetch(:rails_env, fetch(:stage)))
# :sidekiq_log =>  File.join(shared_path, 'log', 'sidekiq.log')
# :sidekiq_options =>  nil
# :sidekiq_require => nil
# :sidekiq_tag => nil
# :sidekiq_config => nil
# :sidekiq_queue => nil
# :sidekiq_timeout =>  10
# :sidekiq_role =>  :app
# :sidekiq_processes =>  1
# :sidekiq_concurrency => nil
# :sidekiq_cmd => "#{fetch(:bundle_cmd, "bundle")} exec sidekiq"  # Only for capistrano2.5
# :sidekiqctl_cmd => "#{fetch(:bundle_cmd, "bundle")} exec sidekiqctl" # Only for capistrano2.5

set :sidekiq_config, "#{current_path}/config/sidekiq.yml"

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
      invoke 'sidekiq:restart'
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   puma.restart
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end

# namespace :deploy do
#   desc 'Restart Passenger'
#   task :restart do
#     on roles(:app), in: :sequence, wait: 5 do
#       execute :touch, release_path.join('tmp/restart.txt')
#     end
#   end
#
#   after :publishing, 'deploy:restart'
#   after :finishing,  'deploy:cleanup'
# end
