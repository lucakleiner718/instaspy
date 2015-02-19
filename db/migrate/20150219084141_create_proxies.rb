class CreateProxies < ActiveRecord::Migration
  def change
    create_table :proxies do |t|
      t.string :url
      t.string :login
      t.string :password
      t.boolean :active, default: true
      t.string :provider

      t.timestamps
    end
  end
end
