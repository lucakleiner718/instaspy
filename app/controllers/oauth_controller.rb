class OauthController < ApplicationController
  def connect
    if params[:key].present?
      account = InstagramAccount.where(client_id: params[:key]).first
    else
      account = InstagramAccount.all.sample
    end

    Instagram.configure do |config|
      config.client_id = account.client_id
      config.client_secret = account.client_secret
      config.no_response_wrapper = true
    end

    InstagramAccount.where(login_process: true).update_all(login_process: false)

    account.update_attribute :login_process, true
    session[:ig_account] = account.id
    redirect_to Instagram.authorize_url(redirect_uri: account.redirect_uri)
  end

  def signin
    if session[:ig_account].present?
      account = InstagramAccount.find(session[:ig_account])
    else
      account = InstagramAccount.where(login_process: true).first
      account.update_column :login_process, false if account
    end

    Rails.logger.info "Processing with account #{account.id}; session: #{session[:ig_account]};"

    raise unless account

    Instagram.configure do |config|
      config.client_id = account.client_id
      config.client_secret = account.client_secret
      config.no_response_wrapper = true
    end

    response = Instagram.get_access_token(params[:code], redirect_uri: account.redirect_uri)

    login = InstagramLogin.where(account_id: account.id, ig_id: response.user.id).first_or_initialize
    login.access_token = response.access_token
    login.save

    user = User.where(insta_id: response.user.id).first_or_initialize
    user.insta_data response.user
    user.save

    account.login_process = false
    account.save

    redirect_to clients_status_path
  end
end
