class CreateMedia < ActiveRecord::Migration
  def change
    create_table :media do |t|
      t.string :insta_id
      t.string :insta_type
      t.string :filter
      t.text :text
      t.integer :likes_amount
      t.string :link
      t.integer :user_id
      t.datetime :created_time
      t.text :images
      t.text :videos

      t.timestamps
    end
  end
end
