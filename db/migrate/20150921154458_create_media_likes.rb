class CreateMediaLikes < ActiveRecord::Migration
  def change
    create_table :media_likes do |t|
      t.integer :media_id
      t.integer :user_id
      t.datetime :liked_at, null: false
    end

    add_index :media_likes, :media_id
    add_index :media_likes, :user_id
    add_index :media_likes, [:media_id, :user_id], unique: true
    add_index :media_likes, :liked_at
  end
end
