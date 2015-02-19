class AddLocationFieldsToUser < ActiveRecord::Migration
  def change
    add_column :users, :location_country, :string
    add_column :users, :location_state, :string
    add_column :users, :location_city, :string
    add_column :users, :location_updated_at, :datetime
    add_column :users, :avg_likes, :integer
    add_column :users, :avg_likes_updated_at, :datetime
  end
end
