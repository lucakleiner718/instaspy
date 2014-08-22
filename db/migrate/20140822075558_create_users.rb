class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.integer :insta_id
      t.string :username
      t.string :full_name
      t.string :profile_picture
      t.text :bio
      t.string :website
      t.integer :follows
      t.integer :followed_by
      t.integer :media_amount

      t.timestamps
    end
  end
end
