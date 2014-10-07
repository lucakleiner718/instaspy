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

    account.update_attribute :login_process, true
    redirect_to Instagram.authorize_url(redirect_uri: account.redirect_uri)
  end

  def signin
    account = InstagramAccount.where(login_process: true).first

    response = Instagram.get_access_token(params[:code], redirect_uri: account.redirect_uri)

    account.login_process = false
    account.access_token = response.access_token
    account.save

    redirect_to root_path
  end
end
