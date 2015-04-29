class RemoveMediaCountFromTags < ActiveRecord::Migration
  def change
    remove_column :tags, :media_count
  end
end
