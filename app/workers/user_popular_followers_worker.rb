class UserPopularFollowersWorker

  include Sidekiq::Worker
  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    begin
      user = User.find(user_id)
      user.get_popular_followers_percentage
    rescue ActiveRecord::RecordNotFound => e
      return
    end
  end
end