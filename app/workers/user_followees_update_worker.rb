class UserFolloweesUpdateWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    user = User.find(user_id)
    followees_ids = Follower.where(follower_id: user.id).pluck(:user_id)
    if followees_ids.size < user.follows * 0.9
      UserFolloweesCollectWorker.perform_async user.id, ignore_exists: true
    end
    followees_ids.in_groups_of(10_000, false) do |ids|
      User.where(id: ids).outdated.pluck(:id).each do |id|
        UserUpdateWorker.perform_async id
      end
    end
    if followees_ids.size > user.follows * 0.9
      user.followees_info_updated_at = Time.now
      user.save
    end
  end

end