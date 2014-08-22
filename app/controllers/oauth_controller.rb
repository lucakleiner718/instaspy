class OauthController < ApplicationController
  def connect
    redirect_to Instagram.authorize_url(:redirect_uri => ENV['REDIRECT_URI'])
  end

  def signin
    response = Instagram.get_access_token(params[:code], :redirect_uri => ENV['REDIRECT_URI'])
    Setting.s('instagram_access_token', response.access_token)
    session[:access_token] = response.access_token
    redirect_to root_path
  end
end
