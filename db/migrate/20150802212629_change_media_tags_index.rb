class ChangeMediaTagsIndex < ActiveRecord::Migration
  disable_ddl_transaction!

  def up
    duplicates = ActiveRecord::Base.connection.execute("
      select media_id, tag_id from (
        select media_id, tag_id, count(id) from media_tags group by media_id, tag_id
      ) as a
      where a.count > 1
    ").to_a

    duplicates.each do |row|
      ids = MediaTag.where(media_id: row['media_id'], tag_id: row['tag_id']).offset(1).pluck(:id)
      MediaTag.where(id: ids).delete_all
    end

    remove_index :media_tags, column: [:media_id, :tag_id]
    add_index :media_tags, [:media_id, :tag_id], unique: true, algorithm: :concurrently
  end

  def down
    remove_index :media_tags, column: [:media_id, :tag_id]
    add_index :media_tags, [:media_id, :tag_id]
  end
end
