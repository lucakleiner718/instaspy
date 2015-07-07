class CreateTagMediaCounters < ActiveRecord::Migration
  def change
    create_table :tag_media_counters do |t|
      t.integer :tag_id
      t.integer :media_count, default: 0
      t.datetime :updated_at, null: false
    end

    add_index :tag_media_counters, :tag_id
  end
end
