class AddIndexToFollowersFollowedAt < ActiveRecord::Migration
  def change
    add_index :followers, :followed_at
  end
end
