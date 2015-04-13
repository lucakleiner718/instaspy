class UserFollowersWorker

  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def expiration
    @expiration ||= 60*60*24*7
  end

  def perform user_id, *args
    User.find(user_id).update_followers *args
    store user_id: user_id
  end
end