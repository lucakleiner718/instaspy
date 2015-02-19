class UserMediaDataWorker
  include Sidekiq::Worker

  def perform users_ids
    User.where(id: users_ids).each do |user|
      p user.popular_location
    end
  end

  def self.spawn
    User.where('followed_by is null OR followed_by > 1000')
  end
end