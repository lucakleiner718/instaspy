Rails.application.routes.draw do

  root to: 'pages#home'

  get 'oauth/connect'
  get 'oauth/signin'

  get 'export' => 'pages#export'

  get 'chart' => 'pages#chart'
  get 'chart_tag_data' => 'pages#chart_tag_data'

  get 'reports/followers'
  post 'reports/followers' => 'reports#followers_report'

  get 'clients_status' => 'pages#clients_status'

  # require 'sidekiq/web'
  # mount Sidekiq::Web, at: '/sidekiq'

end
