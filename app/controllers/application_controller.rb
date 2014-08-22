class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_filter do
    if Setting.g('instagram_access_token').blank?
      redirect_to oauth_connect_path
    end
  end
end
