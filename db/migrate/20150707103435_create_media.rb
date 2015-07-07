class CreateMedia < ActiveRecord::Migration
  def change
    create_table :media do |t|
      t.string :insta_id
      t.datetime :created_time
      t.integer :likes_amount
      t.integer :comments_amount
      t.string :link
      t.decimal :location_lat, precision: 10, scale: 6
      t.decimal :location_lng, precision: 10, scale: 6
      t.string :location_name
      t.string :location_city
      t.string :location_state
      t.string :location_country
      t.boolean :location_present, default: nil
      t.text :tag_names, array: true, default: []
      t.string :image
      t.integer :user_id

      t.timestamps null: false
    end

    add_index :media, :created_at
    add_index :media, :updated_at
    add_index :media, :created_time
    add_index :media, :location_city
    add_index :media, :location_country
    add_index :media, :location_state
    add_index :media, :user_id
    add_index :media, :insta_id, unique: true
  end
end
