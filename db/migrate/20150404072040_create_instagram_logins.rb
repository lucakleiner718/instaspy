class CreateInstagramLogins < ActiveRecord::Migration
  def change
    create_table :instagram_logins do |t|
      t.integer :account_id
      t.integer :ig_id
      t.string :access_token

      t.timestamps
    end
  end
end
