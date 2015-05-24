class OauthController < ApplicationController
  def connect
    if params[:key].present?
      account = InstagramAccount.where(client_id: params[:key]).first
    else
      account = InstagramAccount.all.sample
    end

    session[:ig_account] = account.id
    redirect_to Instagram.authorize_url(redirect_uri: account.redirect_uri,
        client_id: account.client_id, client_secret: account.client_secret, no_response_wrapper: true)
  end

  def signin
    if session[:ig_account].present?
      account = InstagramAccount.find(session[:ig_account])
    else
      account = InstagramAccount.first
    end

    Rails.logger.info "Processing with account #{account.id}; session: #{session[:ig_account]};"

    raise unless account

    response = Instagram.get_access_token(params[:code],
                  redirect_uri: account.redirect_uri, client_id: account.client_id, client_secret: account.client_secret, no_response_wrapper: true)

    login = InstagramLogin.where(account_id: account.id, ig_id: response.user.id).first_or_initialize
    login.access_token = response.access_token
    login.save

    user = User.where(insta_id: response.user.id).first_or_initialize
    user.set_data response.user
    user.save

    account.save

    redirect_to clients_status_path(page: session[:clients_status_page])
  end
end
