class UserWorker
  include Sidekiq::Worker

  sidekiq_options queue: :middle, unique: true, unique_args: -> (args) { [ args.first ] },
    unique_unlock_order: :before_yield

  def perform user_id, *args
    options = args.extract_options!
    if args.size == 1 && args.first.is_a?(TrueClass)
      options[:force] = args.first
    end

    begin
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound => e
      return
    end

    options.symbolize_keys!

    user.update_info! options if user
  end

  def self.spawn amount=10_000
    User.where(grabbed_at: nil).limit(amount).order(updated_at: :desc).pluck(:id).each do |user_id|
      self.perform_async user_id
    end
  end
end