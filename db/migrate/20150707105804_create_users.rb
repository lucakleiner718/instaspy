class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :insta_id, limit: 20
      t.string :username
      t.string :full_name
      t.string :bio
      t.string :website
      t.integer :follows
      t.integer :followed_by
      t.integer :media_amount
      t.boolean :private, default: false
      t.datetime :grabbed_at
      t.string :email
      t.string :location_country
      t.string :location_state
      t.string :location_city
      t.datetime :location_updated_at
      t.integer :avg_likes
      t.datetime :avg_likes_updated_at
      t.integer :avg_comments
      t.datetime :avg_comments_updated_at
      t.datetime :followers_updated_at
      t.datetime :followees_updated_at

      t.timestamps null: false
    end

    add_index :users, :insta_id, unique: true
    add_index :users, :username, unique: true
    add_index :users, :avg_comments
    add_index :users, :avg_comments_updated_at
    add_index :users, :avg_likes
    add_index :users, :avg_likes_updated_at
    add_index :users, :created_at
    add_index :users, :updated_at
    add_index :users, :email
    add_index :users, :website
    add_index :users, :follows
    add_index :users, :followed_by
    add_index :users, :media_amount
    add_index :users, :grabbed_at
    add_index :users, :location_city
    add_index :users, :location_country
    add_index :users, :location_state
  end
end
