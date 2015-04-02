class AddMediaCountToTags < ActiveRecord::Migration
  def change
    add_column :tags, :media_count, :integer, default: 0, null: false
    add_index :tags, :media_count
  end
end
