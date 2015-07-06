Rails.application.routes.draw do

  get 'users' => 'users#index', as: :users
  get 'users/:id/followers.csv' => 'users#followers', as: :users_followers
  get 'users/:id/followees.csv' => 'users#followees', as: :users_followees

  root to: 'pages#home'

  get 'oauth/connect'
  get 'oauth/signin'

  get 'export' => 'pages#export'

  get 'chart' => 'pages#chart'
  get 'chart_tag_data' => 'pages#chart_tag_data'
  get 'chart/amounts' => 'pages#chart_amounts'

  get 'reports' => 'reports#index'
  get 'reports/new' => 'reports#new', as: :new_report
  post 'reports' => 'reports#create'
  patch 'reports/:id/update_status' => 'reports#update_status', as: :report_update_status

  get 'reports/followers'
  post 'reports/followers' => 'reports#followers_report'

  get 'clients_status' => 'pages#clients_status'

  get 'tag_media/added' => 'pages#tag_media_added_check'
  post 'tag_media/added' => 'pages#tag_media_added'

  get 'tags' => 'tags#index'
  get 'tags/observe' => 'tags#observe', as: :tags_observe
  post 'tags/observe' => 'tags#observe_process'

  get 'media/chart' => 'pages#media_chart', as: :media_chart

  require 'sidekiq/web'
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    username == 'rob' && password == 'awesomeLA'
  end if Rails.env.production?
  mount Sidekiq::Web, at: "/sidekiq"

end
