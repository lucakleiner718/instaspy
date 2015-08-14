class UserFollowersAnalyticsWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id, recount: false
    user = User.find(user_id)
    user.get_followers_analytics recount: recount
  end

end