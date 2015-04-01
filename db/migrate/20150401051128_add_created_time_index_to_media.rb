class AddCreatedTimeIndexToMedia < ActiveRecord::Migration
  def change
    add_index :media, :created_time
    add_index :media, :created_at
    add_index :media, :updated_at
  end
end
