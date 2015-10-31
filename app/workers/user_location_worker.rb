class UserLocationWorker

  include Sidekiq::Worker
  sidekiq_options unique: :until_executed, unique_args: -> (args) { [ args.first ] }

  def perform user_id
    begin
      user = User.find(user_id)
      user.update_location!
    rescue ActiveRecord::RecordNotFound => e
    end
  end

  def self.spawn
    User.where('followed_by is null OR followed_by > 1000')
      .where('location_updated_at is null OR location_updated_at < ?', 3.months.ago)
      .select(:id).find_in_batches(batch_size: 1000) do |users_group|

      users_group.each do |user|
        self.perform_async user.id
      end
    end
  end
end