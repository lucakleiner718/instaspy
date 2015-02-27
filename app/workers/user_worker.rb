class UserWorker
  include Sidekiq::Worker

  sidekiq_options unique: true, unique_args: -> (args) { [ args.first ] }

  def perform users
    User.where(id: users).each do |u|
      u.update_info!
      p "Updated #{u.username}"
    end
  end

  def self.spawn
    # User.where(follows: nil).order(created_at: :desc).pluck(:id).in_groups_of(100, false).each do |users|
    User.where(grabbed_at: nil).pluck(:id).each do |user_id|
      self.perform_async [user_id]
    end
  end
end