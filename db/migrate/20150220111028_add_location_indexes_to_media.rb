class AddLocationIndexesToMedia < ActiveRecord::Migration
  def change
    add_index :media, :location_country
    add_index :media, :location_state
    add_index :media, :location_city
  end
end
