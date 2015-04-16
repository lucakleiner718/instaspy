class UserAvgLikesWorker

  include Sidekiq::Worker

  sidekiq_options queue: :low, unique: true, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    begin
      user = User.find(user_id)
    rescue ActiveRecord::RecordNotFound => e
      return true
    end

    user.update_avg_data!
  end

  def self.spawn in_batch=100
    User.where('followed_by is null OR followed_by > 1000')
      .where('avg_likes_updated_at is null OR avg_likes_updated_at < ?', 1.month.ago)
      .select(:id).find_in_batches(batch_size: in_batch) do |users_group|

      self.perform_async users_group.map(&:id)
    end
  end
end