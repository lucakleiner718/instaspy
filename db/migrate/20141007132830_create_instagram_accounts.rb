class CreateInstagramAccounts < ActiveRecord::Migration
  def change
    create_table :instagram_accounts do |t|
      t.string :client_id
      t.string :client_secret
      t.string :redirect_uri
      t.string :access_token
      t.boolean :login_process, default: false

      t.timestamps
    end

    add_index :instagram_accounts, :client_id, unique: true
  end
end
