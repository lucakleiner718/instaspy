schedule_file = Rails.root.join("config/scheduler.yml")
Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file) if File.exists?(schedule_file)