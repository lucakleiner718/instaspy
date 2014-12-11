class UserFolloweesWorker

  include Sidekiq::Worker

  def perform user_id
    user = User.get user_id
    user.update_followees
  end
end