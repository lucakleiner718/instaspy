class CreateInstagramLogins < ActiveRecord::Migration
  def change
    create_table :instagram_logins do |t|
      t.integer :ig_id
      t.string :access_token
      t.integer :account_id

      t.timestamps null: false
    end

    add_index :instagram_logins, :account_id
  end
end
