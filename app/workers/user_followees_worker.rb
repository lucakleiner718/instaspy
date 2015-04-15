class UserFolloweesWorker

  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    user = User.get user_id
    user.update_followees
  end
end