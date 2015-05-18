class UserFollowersWorker

  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) {
      if args[1] && args[1][:start_cursor]
        args
      else
        [ args.first ]
      end
    }

  def perform user_id, *args
    User.find(user_id).update_followers args.extract_options!
  end
end