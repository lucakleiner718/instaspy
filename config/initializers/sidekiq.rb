Sidekiq.default_worker_options = {
  backtrace: true,
  retry: false
}

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://localhost:6379/12', namespace: "instaspy_#{Rails.env}" }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379/12', namespace: "instaspy_#{Rails.env}" }
end

SidekiqUniqueJobs.config.unique_args_enabled = true