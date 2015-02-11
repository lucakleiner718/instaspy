class AddLocationPresentToMedia < ActiveRecord::Migration
  def change
    add_column :media, :location_present, :boolean
  end
end
