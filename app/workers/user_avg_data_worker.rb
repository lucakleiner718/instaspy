class UserAvgDataWorker
  include Sidekiq::Worker

  sidekiq_options queue: :low, unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    user = User.find(user_id)
    user.update_avg_data!
  end
end