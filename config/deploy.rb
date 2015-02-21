# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, 'instaspy'
set :repo_url, 'git@github.com:luxagency/instaspy.git'

set :branch, :master
set :scm, :git
set :format, :pretty
set :pty, false

set :log_level, :info #:debug

set :linked_files, %w{config/database.yml config/mongoid.yml .env config/procs.god}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/reports}

set :keep_releases, 5

set :deploy_to, '/home/app/instaspy'

set :puma_conf, "#{shared_path}/puma.rb"
set :puma_role, :app
set :puma_workers, 2
set :puma_preload_app, false
set :puma_threads, [0, 4]

set :sidekiq_timeout, 60
set :sidekiq_run_in_background, false

set :rvm_ruby_version, '2.1.1@instaspy'

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
      # invoke 'sidekiq:restart'
    end
  end

  after :publishing, :restart

end

namespace :god do

  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, 'god terminate'
          execute :bundle, :exec, 'god -c config/procs.god'
        end
      end
    end
  end

  task :start do
    on roles(:app), in: :sequence, wait: 5 do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, 'god -c config/procs.god'
        end
      end
    end
  end

  task :stop do
    on roles(:app), in: :sequence, wait: 5 do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, 'god terminate'
        end
      end
    end
  end

end

after 'deploy:publishing', 'god:restart'
