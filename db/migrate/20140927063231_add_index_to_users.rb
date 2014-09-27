class AddIndexToUsers < ActiveRecord::Migration
  def change
    add_index :users, :website
  end
end
