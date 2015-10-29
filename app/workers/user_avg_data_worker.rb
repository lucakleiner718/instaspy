class UserAvgDataWorker

  include Sidekiq::Worker
  sidekiq_options unique: :until_executed, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    begin
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.debug e.message
      return false
    end
    user.update_avg_data!
  end
end