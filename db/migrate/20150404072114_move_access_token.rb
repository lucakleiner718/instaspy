class MoveAccessToken < ActiveRecord::Migration
  def change
    remove_column :instagram_accounts, :access_token
  end
end
