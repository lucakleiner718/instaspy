class AddAvgCommentsFieldsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :avg_comments, :integer
    add_column :users, :avg_comments_updated_at, :datetime

    add_index :users, :avg_comments
    add_index :users, :avg_comments_updated_at
  end
end
