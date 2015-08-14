class AddDataToUsers < ActiveRecord::Migration
  def change
    add_column :users, :data, :json, default: {}
    remove_column :users, :followers_analytics, :json, default: {}
    remove_column :users, :followers_analytics_updated_at, :datetime
  end
end
