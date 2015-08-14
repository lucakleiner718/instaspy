class UserFolloweesWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id, *args
    User.find(user_id).update_followees *args
  end
end