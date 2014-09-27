class RemoveColumnsFromMedia < ActiveRecord::Migration
  def up
    remove_column :media, :insta_type
    remove_column :media, :filter
    remove_column :media, :text
    remove_column :media, :likes_amount
    remove_column :media, :link
    remove_column :media, :images
    remove_column :media, :videos

    remove_column :users, :profile_picture
    remove_column :tags, :media_count
  end

  def down
    add_column :media, :insta_type, :string
    add_column :media, :filter, :string
    add_column :media, :text, :text
    add_column :media, :likes_amount, :integer
    add_column :media, :link, :string
    add_column :media, :images, :text
    add_column :media, :videos, :text

    add_column :users, :profile_picture, :string
    add_column :tags, :media_count, :integer
  end
end
