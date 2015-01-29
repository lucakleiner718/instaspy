class UserWorker
  include Sidekiq::Worker

  def perform
    User.not_grabbed.not_private.order(created_at: :desc).find_each { |u| u.update_info! }
  end
end