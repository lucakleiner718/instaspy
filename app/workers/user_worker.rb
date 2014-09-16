class UserWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false, backtrace: true, unique: true

  def perform
    User.not_grabbed.limit(1000).each do |u|
      u.update_info!
    end
  end
end