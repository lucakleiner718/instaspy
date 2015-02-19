class AddIndexToUsersNewFieldsLocation < ActiveRecord::Migration
  def change
    add_index :users, :location_country
    add_index :users, :location_state
    add_index :users, :location_city
    add_index :users, :avg_likes
    add_index :users, :avg_likes_updated_at
  end
end
