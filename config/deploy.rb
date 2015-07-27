# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, 'instaspy'
set :repo_url, 'git@github.com:luxagency/instaspy.git'

set :branch, 'pg'
set :scm, :git
set :format, :pretty
set :pty, true

set :ssh_options, {
  forward_agent: true,
}

set :log_level, :info #:debug

set :linked_files, %w{config/database.yml .env config/procs.god config/sidekiq.yml config/sidekiq2.yml}
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/reports}

set :keep_releases, 5

set :deploy_to, '/home/app/instaspy'

set :puma_conf, "#{shared_path}/puma.rb"
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_role, :web
set :puma_workers, 2
set :puma_preload_app, false
set :puma_threads, [0, 4]

set :sidekiq_timeout, 60
set :sidekiq_run_in_background, false

set :rvm_type, :user
set :rvm_ruby_version, '2.1.1@instaspy'
set :rvm_roles, %w{app web}

set :bundle_binstubs, nil

after 'deploy:restart', 'puma:restart'

set :god_pid, "#{shared_path}/tmp/pids/god.pid"

namespace :god do

  task :restart do
    on roles(:app), in: :parallel do
      within release_path do
        with rails_env: fetch(:rails_env) do
          pid = capture(:cat, fetch(:god_pid))
          execute :kill, pid if test(*("[ -d #{pid} ]").split(' '))
          execute :bundle, :exec, "god -c config/procs.god --pid #{fetch :god_pid}"
        end
      end
    end
  end

  task :start do
    on roles(:app), in: :parallel do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, "god -c config/procs.god --pid #{fetch :god_pid}"
        end
      end
    end
  end

  task :stop do
    on roles(:app), in: :parallel do
      within release_path do
        with rails_env: fetch(:rails_env) do
          pid = capture(:cat, fetch(:god_pid))
          execute :kill, pid if test(*("[ -d #{pid} ]").split(' '))
          # execute :bundle, :exec, 'god terminate' if test(*("[ -f /home/app/instaspy/shared/tmp/pids/god.pid ]").split(' '))
        end
      end
    end
  end

end

after 'deploy:publishing', 'god:restart'

after "deploy:updated", "newrelic:notice_deployment"
