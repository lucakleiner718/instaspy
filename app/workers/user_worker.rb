class UserWorker
  include Sidekiq::Worker

  sidekiq_options queue: :middle, unique: true, unique_args: -> (args) { [ args.first ] }

  def perform users_ids, force=false
    User.where(id: users_ids).each do |u|
      next if u.actual?
      u.update_info! force
    end
  end

  def self.spawn amount=10_000
    User.where(grabbed_at: nil).limit(amount).order(updated_at: :desc).pluck(:id).each do |user_id|
      self.perform_async [user_id]
    end
  end
end