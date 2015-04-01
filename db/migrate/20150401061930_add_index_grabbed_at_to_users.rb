class AddIndexGrabbedAtToUsers < ActiveRecord::Migration
  def change
    add_index :users, :grabbed_at
    add_index :users, :created_at
    add_index :users, :updated_at
    add_index :users, :media_amount
    add_index :users, :followed_by
  end
end
