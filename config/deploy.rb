# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, 'instaspy'
set :repo_url, 'git@github.com:luxagency/instaspy.git'

set :branch, 'master'
set :scm, :git
set :format, :pretty
set :pty, true

set :ssh_options, {
  forward_agent: true,
}

set :log_level, :info #:debug

set :linked_files, %w{config/database.yml .env config/god.rb config/sidekiq.yml config/sidekiq2.yml config/sidekiq-fols.yml}
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

# after 'deploy:restart', 'puma:restart'

set :god_pid, "#{shared_path}/tmp/pids/god.pid"
set :god_config, "#{release_path}/config/god.rb"

namespace :god do
  def god_is_running
    capture(:bundle, "exec god status > /dev/null 2>&1 || echo 'god not running'") != 'god not running'
  end

  # Must be executed within SSHKit context
  def start_god
    execute :bundle, "exec god -c #{fetch :god_config}"
  end

  def stop_all_sidekiq
    execute "kill `ps -ef | grep sidekiq | grep -v grep | awk '{print $2}'`"
  end

  desc "Start god and his processes"
  task :start do
    on roles(:web) do
      within release_path do
        with RAILS_ENV: fetch(:rails_env) do
          start_god
        end
      end
    end
  end

  desc "Terminate god and his processes"
  task :stop do
    on roles(:web) do
      within release_path do
        if god_is_running
          execute :bundle, "exec god terminate"
          stop_all_sidekiq
        end
      end
    end
  end

  desc "Restart god's child processes"
  task :restart do
    on roles(:web) do
      within release_path do
        with RAILS_ENV: fetch(:rails_env) do
          if god_is_running
            execute :bundle, "exec god terminate"
            stop_all_sidekiq
          end
          start_god
        end
      end
    end
  end
end

after "deploy:updated", "god:restart"
after "deploy:updated", "newrelic:notice_deployment"
