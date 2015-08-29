Rails.application.routes.draw do

  get 'users' => 'users#index', as: :users
  post 'users/duplicates' => 'users#duplicates', as: :users_duplicates
  get 'users/export' => 'users#export', as: :users_export
  post 'users/export/process' => 'users#export_process', as: :users_export_process
  get 'users/followers-chart/:id' => 'users#followers_chart', as: :user_followers_chart

  get 'users/scan' => 'users#scan', as: :users_scan
  get 'users/scan/:username' => 'users#scan_show', as: :users_scan_show
  get 'users/scan_requests' => 'users#scan_requests', as: :users_scan_requests
  get 'users/:username/followers.csv' => 'users#followers', as: :user_followers

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
