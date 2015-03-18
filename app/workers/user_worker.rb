class UserWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] },
    queue: :middle

  def perform users
    User.where(id: users).each do |u|
      next if u.grabbed_at.present? && u.grabbed_at > 1.day.ago
      u.update_info!
    end
  end

  def self.spawn amount=10_000
    # User.where(follows: nil).order(created_at: :desc).pluck(:id).in_groups_of(100, false).each do |users|
    User.where(grabbed_at: nil).limit(amount).order(updated_at: :desc).pluck(:id).each do |user_id|
      self.perform_async [user_id]
    end
  end
end