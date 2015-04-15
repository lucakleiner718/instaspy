class AddFollowedAtToFollowers < ActiveRecord::Migration
  def change
    add_column :followers, :followed_at, :datetime
  end
end
