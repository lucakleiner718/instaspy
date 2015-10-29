class UserFollowersPopularWorker

  include Sidekiq::Worker
  sidekiq_options unique: :until_executed, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    begin
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.debug e.message
      return false
    end

    user.get_popular_followers_percentage recount: true
  end
end