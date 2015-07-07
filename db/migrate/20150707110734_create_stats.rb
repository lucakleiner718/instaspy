class CreateStats < ActiveRecord::Migration
  def change
    create_table :stats do |t|
      t.string :key
      t.string :value
      t.timestamps null: false
    end

    add_index :stats, :key
  end
end
