class AddGrabsUsersCsvToTags < ActiveRecord::Migration
  def change
    add_column :tags, :grabs_users_csv, :boolean, default: false
  end
end
