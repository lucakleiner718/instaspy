class UserMediaWorker

  include Sidekiq::Worker
  sidekiq_options queue: :middle, unique: :until_executed, unique_args: -> (args) { [ args.first ] }

  def perform user_id, *args
    options = args.extract_options!
    options.symbolize_keys!

    begin
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound => e
      return
    end

    user.recent_media options if user
  end
end