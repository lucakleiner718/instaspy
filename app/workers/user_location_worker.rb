class UserLocationWorker
  include Sidekiq::Worker

  sidekiq_options queue: :low, retry: 3

  def perform users_id
    User.find(users_id).update_location!
  end

  def self.spawn

    # users = User.where('followed_by is null OR followed_by > 1000').where('location_updated_at is null OR location_updated_at < ?', 3.months.ago).limit(10).pluck(:id)

    User.where('followed_by is null OR followed_by > 1000')
      .where('location_updated_at is null OR location_updated_at < ?', 3.months.ago)
      .select(:id).find_in_batches(batch_size: 1000) do |users_group|

      users_group.each do |user|
        self.perform_async user.id
      end
    end
  end
end