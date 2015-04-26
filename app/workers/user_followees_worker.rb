class UserFolloweesWorker

  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id, *args
    user = User.find(user_id)
    user.update_followees *args
  end
end