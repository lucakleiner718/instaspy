class CreateScanRequests < ActiveRecord::Migration
  def change
    create_table :scan_requests do |t|
      t.string :username
      t.string :email

      t.timestamps null: false
    end
  end
end
