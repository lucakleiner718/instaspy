class UserUpdateFollowersWorker

  include Sidekiq::Worker

  def perform user_id
    followers_ids = Follower.where(user_id: user_id).pluck(:follower_id)
    if followers_ids.size < User.find(user_id).followed_by * 0.9
      UserFollowersWorker.perform_async user_id
    end
    followers_ids.in_groups_of(10_000, false) do |ids|
      User.where(id: ids).outdated.pluck(:id).each do |id|
        UserWorker.perform_async id
      end
    end
  end

end