class UserLocationFixWorker
  include Sidekiq::Worker

  def perform ids
    states = Country['US'].states
    User.where(id: ids).each do |user|
      country = user.location_country
      state = user.location_state
      city = user.location_city

      state.sub!("#{country}, ", '') if state
      city.sub!("#{country}, ", '') if city
      city.sub!("#{state}, ", '') if city

      state = states[state.upcase]['name'] if state && states[state.upcase]

      user.location_country, user.location_state, user.location_city = country, state, city

      user.save
    end
  end

  def self.spawn
    users = User.where(location_country: 'US').where('location_state like ?', 'US,%').pluck(:id)
    users.in_groups_of(1_000, false) do |ids|
      self.perform_async ids
    end
  end
end