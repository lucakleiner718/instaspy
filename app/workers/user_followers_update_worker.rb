class UserFollowersUpdateWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    user = User.find(user_id)
    followers_ids = Follower.where(user_id: user.id).pluck(:follower_id)
    if followers_ids.size < user.followed_by * 0.9
      UserFollowersCollectWorker.perform_async user.id, ignore_exists: true
    end
    followers_ids.in_groups_of(10_000, false) do |ids|
      User.where(id: ids).outdated.pluck(:id).each do |id|
        UserUpdateWorker.perform_async id
      end
    end
    if followers_ids.size > user.followed_by * 0.9
      user.followers_info_updated_at = Time.now
      user.save
    end
  end

end