class CreateMediaTags < ActiveRecord::Migration
  def change
    create_table :media_tags do |t|
      t.integer :tag_id
      t.integer :media_id
    end

    add_index :media_tags, :media_id
    add_index :media_tags, :tag_id
    add_index :media_tags, [:media_id, :tag_id]
  end
end
