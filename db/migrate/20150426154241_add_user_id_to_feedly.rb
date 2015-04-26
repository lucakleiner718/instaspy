class AddUserIdToFeedly < ActiveRecord::Migration
  def change
    add_column :feedly, :user_id, :integer
  end
end
