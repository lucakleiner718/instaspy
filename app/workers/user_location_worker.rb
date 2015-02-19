class UserLocationWorker
  include Sidekiq::Worker

  def perform users_ids
    User.where(id: users_ids).each do |user|
      user.popular_location
    end
  end

  def self.spawn in_batch=100
    User.where('followed_by is null OR followed_by > 1000')
      .where('location_updated_at is null OR location_updated_at < ?', 1.month.ago)
      .select(:id).find_in_batches(batch_size: in_batch) do |users_group|

      self.perform_async users_group.map(&:id)
    end
  end
end