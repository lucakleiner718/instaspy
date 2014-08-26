require 'sidekiq/scheduler'
Sidekiq.schedule = YAML.load_file(Rails.root.join("config/scheduler.yml"))