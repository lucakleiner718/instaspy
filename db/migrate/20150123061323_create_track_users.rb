class CreateTrackUsers < ActiveRecord::Migration
  def change
    create_table :track_users do |t|
      t.integer :user_id
      t.boolean :followees, default: false
      t.boolean :followers, default: false

      t.timestamps
    end
  end
end
