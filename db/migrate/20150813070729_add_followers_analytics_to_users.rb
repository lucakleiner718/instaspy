class AddFollowersAnalyticsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :followers_analytics, :json, default: {}
    add_column :users, :followers_analytics_updated_at, :datetime
  end
end
