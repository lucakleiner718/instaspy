class AddLatAndLngToMedia < ActiveRecord::Migration
  def change
    add_column :media, :location_lat, :float
    add_column :media, :location_lng, :float
    add_column :media, :location_name, :string
    add_column :media, :location_city, :string
    add_column :media, :location_state, :string
    add_column :media, :location_country, :string
  end
end
