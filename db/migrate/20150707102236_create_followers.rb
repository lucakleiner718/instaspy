class CreateFollowers < ActiveRecord::Migration
  def change
    create_table :followers do |t|
      t.integer :user_id
      t.integer :follower_id
      t.datetime :followed_at
      t.datetime :created_at, null: false
    end

    add_index :followers, [:user_id, :follower_id], unique: true
    add_index :followers, :follower_id
    add_index :followers, :user_id
    add_index :followers, :followed_at
  end
end
