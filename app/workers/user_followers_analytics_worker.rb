class UserFollowersAnalyticsWorker

  include Sidekiq::Worker
  sidekiq_options unique: :until_and_while_executing, unique_args: -> (args) { [ args.first ] }

  def perform user_id, recount: false
    begin
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.debug e.message
      return false
    end
    user.get_followers_analytics recount: recount
  end

end