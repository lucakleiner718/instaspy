class UsersController < ApplicationController
  def index
    @users = User.order(created_at: :desc).page(params[:page]).per(20)
  end

  def followers
  end

  def followees
  end
end
