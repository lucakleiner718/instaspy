class AddIndexesToFollowers < ActiveRecord::Migration
  def change
    add_index :followers, :user_id
    add_index :followers, :follower_id
  end
end
