VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join "spec", "vcr_cassettes"
  config.hook_into :faraday
  config.default_cassette_options = { record: :new_episodes }
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = true
  # config.ignore_hosts 'api.linkedin.com'
  config.debug_logger = $stderr
  # config.hook_into :webmock # or :fakeweb
end