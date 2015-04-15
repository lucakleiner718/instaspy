class UserFollowersWorker

  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  sidekiq_options unique: true, unique_args: -> (args) {
      if args[1] && args[1][:start_cursor]
        args
      else
        [ args.first ]
      end
    }

  def expiration
    @expiration ||= 60*60*24*7
  end

  def perform user_id, *args
    User.find(user_id).update_followers *args
    store user_id: user_id
  end
end