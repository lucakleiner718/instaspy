class AddIndexesToMedia < ActiveRecord::Migration
  def change
    add_index :media, :insta_id, unique: true
    add_index :media, :user_id
    add_index :users, :insta_id, unique: true
    add_index :tags, :name, unique: true
    add_index :tags, :grabs_users_csv
    add_index :tags, :observed
  end
end
