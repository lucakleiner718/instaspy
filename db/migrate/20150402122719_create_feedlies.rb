class CreateFeedlies < ActiveRecord::Migration
  def change
    create_table :feedly do |t|
      t.string :website
      t.string :feed_id
      t.integer :subscribers_amount
      t.datetime :grabbed_at

      t.timestamps
    end

    add_index :feedly, :feed_id, unique: true
  end
end
