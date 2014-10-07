class OauthController < ApplicationController
  def connect
    session[:insta_index] = InstaClient.new.index
    redirect_to Instagram.authorize_url(redirect_uri: Rails.application.secrets.instagram_redirect_uri)
  end

  def signin
    response = Instagram.get_access_token(params[:code], redirect_uri: Rails.application.secrets.instagram_redirect_uri)
    Setting.s(Rails.application.secrets.instagram_client_id[session[:insta_index]], response.access_token)
    redirect_to root_path
  end
end
