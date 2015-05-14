class UserFolloweesWorker

  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id, **options
    User.find(user_id).update_followees **options
  end
end