class UsersController < ApplicationController
  def index
    @users = User.order(created_at: :desc).page(params[:page]).per(20)
  end

  def show
    @user = User.find_by(username: params[:id])

    data = Follower.collection.aggregate(
      { "$match" => { user_id: @user.id, followed_at: { '$ne' => nil } } },
      { "$group" => {
        _id: { month: { "$month" => "$followed_at" }, year: { "$year" => "$followed_at" } },
        count: { "$sum" => 1 } } },
      { "$sort" => { followed_at: 1 } }
    )
    data = data.inject({}) do |obj, el|
      date = DateTime.parse("#{el['_id']['year']}/#{el['_id']['month']}/1").to_i * 1000
      obj[date] = el['count']
      obj
    end
    @data = data.sort
  end

end
