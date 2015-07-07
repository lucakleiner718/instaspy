class CreateFeedly < ActiveRecord::Migration
  def change
    create_table :feedly do |t|
      t.string :website
      t.string :feed_id
      t.string :feedly_url
      t.integer :subscribers_amount
      t.datetime :grabbed_at
      t.integer :user_id

      t.timestamps null: false
    end

    add_index :feedly, :feed_id, unique: true
    add_index :feedly, :website
  end
end
