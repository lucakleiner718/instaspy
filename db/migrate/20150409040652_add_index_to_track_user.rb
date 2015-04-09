class AddIndexToTrackUser < ActiveRecord::Migration
  def change
    add_index :track_users, :user_id, unique: true
    add_index :observed_tags, :tag_id, unique: true
    add_index :instagram_logins, [:account_id, :ig_id], unique: true
  end
end
