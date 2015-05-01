Sidekiq.default_worker_options = {
  backtrace: true,
  retry: false
}

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://45.55.202.12:6379/12', namespace: "instaspy_#{Rails.env}" }
  # config.server_middleware do |chain|
  #   chain.add Sidekiq::Status::ServerMiddleware, expiration: 30.minutes # default
  # end
  # config.client_middleware do |chain|
  #   chain.add Sidekiq::Status::ClientMiddleware
  # end
  # config.error_handlers << Proc.new { |ex, context| Airbrake.notify_or_ignore(ex, parameters: context) }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://45.55.202.12:6379/12', namespace: "instaspy_#{Rails.env}" }
  # config.client_middleware do |chain|
  #   chain.add Sidekiq::Status::ClientMiddleware
  # end
end

SidekiqUniqueJobs.config.unique_args_enabled = true
