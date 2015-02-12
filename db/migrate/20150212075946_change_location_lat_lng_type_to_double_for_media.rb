class ChangeLocationLatLngTypeToDoubleForMedia < ActiveRecord::Migration
  def up
    change_column :media, :location_lat, :double
    change_column :media, :location_lng, :double
  end

  def down
    change_column :media, :location_lat, :float
    change_column :media, :location_lng, :float
  end
end
