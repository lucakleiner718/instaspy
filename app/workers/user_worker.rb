class UserWorker
  include Sidekiq::Worker

  def perform users
    User.where(id: users).each { |u| u.update_info! }
  end

  def self.spawn
    User.where(follows: nil).order(created_at: :desc).pluck(:id).in_groups_of(100, false).each do |users|
      self.perform_async users
    end
  end
end