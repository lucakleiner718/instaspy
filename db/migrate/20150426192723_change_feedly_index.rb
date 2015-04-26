class ChangeFeedlyIndex < ActiveRecord::Migration
  def change
    remove_index :feedly, :feed_id
    add_index :feedly, :feed_id
  end
end
