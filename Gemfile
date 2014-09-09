source 'https://rubygems.org'

ruby '2.1.1'
#ruby-gemset=instaspy

gem 'rails', '4.1.5'                      # Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'mysql2'                              # Use mysql as the database for Active Record

gem 'sass-rails', '~> 4.0.3'              # Use SCSS for stylesheets
gem 'uglifier', '>= 1.3.0'                # Use Uglifier as compressor for JavaScript assets
gem 'coffee-rails', '~> 4.0.0'            # Use CoffeeScript for .js.coffee assets and views
gem 'therubyracer',  platforms: :ruby     # See https://github.com/sstephenson/execjs#readme for more supported runtimes
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
  gem 'capistrano3-puma', require: false
  gem 'capistrano-rvm', '~> 0.1', require: false
  gem "capistrano-sidekiq", require: false

  gem 'thin'
end

group :production do
  gem 'puma', '~> 2.8.2'                                    # Production Web Server
end

gem 'pry-rails'
gem 'instagram'
gem 'httparty'
gem 'render_csv'
gem 'sidekiq'                             # Delayed jobs processor
# gem "sidekiq-cron", "~> 0.2.0"
gem 'sidekiq-failures'
gem 'sidekiq-unique-jobs'
gem 'sinatra', require: false             # Web interface of Sidekiq processes
gem 'slim'
gem 'dotenv', '~> 0.11.1'
gem 'dotenv-deployment', require: 'dotenv/deployment'       # Automatic Vars in Production/Staging
gem 'whenever', :require => false