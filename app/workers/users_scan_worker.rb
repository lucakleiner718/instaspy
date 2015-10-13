class UsersScanWorker

  include Sidekiq::Worker
  sidekiq_options queue: :critical, unique: :until_and_while_executing, unique_args: -> (args) { [ args.first ] }

  def perform user_id, *args
    user = User.find(user_id)

    UserFollowersCollectWorker.perform_async user.id if user.followers_size < user.followed_by * 0.9
    UserLocationWorker.perform_async user.id unless user.location?
    UserAvgDataWorker.perform_async user.id unless user.avg_comments_updated_at
  end
end