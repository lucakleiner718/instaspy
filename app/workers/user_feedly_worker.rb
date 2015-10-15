class UserFeedlyWorker

  include Sidekiq::Worker
  sidekiq_options unique: :until_executed, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    user = User.find(user_id)
    user.update_feedly!
  end
end