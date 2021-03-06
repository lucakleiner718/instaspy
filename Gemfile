source 'https://rubygems.org'

ruby '2.1.1'
#ruby-gemset=instaspy

gem 'rails', '4.2.3'                      # Bundle edge Rails instead: gem 'rails', github: 'rails/rails'

gem 'sass-rails', '~> 5.0.4'              # Use SCSS for stylesheets
gem 'uglifier', '>= 1.3.0'                # Use Uglifier as compressor for JavaScript assets
gem 'coffee-rails', '~> 4.0.0'            # Use CoffeeScript for .js.coffee assets and views
# gem 'therubyracer', platforms: :ruby     # See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'jquery-rails'                        # Use jquery as the JavaScript library
gem 'jbuilder', '~> 2.0'                  # Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder

group :development do
  gem 'spring'                            # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'quiet_assets'
  gem 'better_errors'
  gem 'binding_of_caller'

  gem 'capistrano', '~> 3.2.0'
  gem 'capistrano-bundler', '~> 1.1', require: false
  gem 'capistrano-rails', '~> 1.1', require: false
  gem 'capistrano-rvm', '~> 0.1', require: false

  gem 'thin'
  gem 'web-console', '~> 2.0'
end

group :development, :test do
  gem 'rspec-rails', '~> 3.0'
  gem 'factory_girl_rails'
  gem 'spring-commands-rspec'
  gem 'guard-rspec', require: false
  gem 'vcr'
  gem 'database_cleaner'
  gem 'webmock', require: false
end

group :production do
  gem 'puma', '~> 2.8.2'
end

gem 'jquery-ui-rails'
gem 'pry-rails'
gem 'instagram', '~> 1.1.6'
gem 'httparty'
gem 'render_csv'

gem 'sidekiq', '~> 4.1.0'
source "https://b76a1d1d:0f27412d@gems.contribsys.com/" do
  gem 'sidekiq-pro', '~> 3.1.0'
end
gem 'sidekiq-failures', '~> 0.4.5'
gem 'sidekiq-unique-jobs', '~> 4.0'
gem 'redis-namespace'

gem 'sinatra', require: false # Web interface of Sidekiq processes
gem 'slim'
gem 'dotenv', '~> 0.11.1'
gem 'dotenv-deployment', require: 'dotenv/deployment'       # Automatic Vars in Production/Staging
gem 'god'
gem 'redis', '~> 3.2'
gem 'redis-rails'
gem 'daemons'
gem 'rubyzip', require: 'zip'
gem 'clockwork'
gem 'nokogiri'
gem 'curb'
gem 'pg'
gem 'fog'
gem 'net-sftp'
gem 'geocoder', github: 'antonzaytsev/geocoder', branch: 'patch-1'
gem 'countries'
gem 'bootstrap-sass', '~> 3.3.4', github: 'twbs/bootstrap-sass'
gem 'kaminari'
gem 'kaminari-bootstrap'
gem 'colorize'
gem 'rgeo'
gem 'rgeo-shapefile'
# gem 'feedlr'
gem 'feedlr', github: 'khelll/feedlr'
gem 'newrelic_rpm'
gem 'simple_form'
gem 'pluck_to_hash'
gem 'bourbon'
