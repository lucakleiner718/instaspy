class UserWorker
  include Sidekiq::Worker

  # sidekiq_options queue: "user"

  def perform
    User.not_grabbed.each do |u|
      u.update_info!
    end
  end
end