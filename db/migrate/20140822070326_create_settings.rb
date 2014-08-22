class CreateSettings < ActiveRecord::Migration
  def change
    create_table :settings do |t|
      t.string :key, unique: true
      t.text :value

      t.timestamps
    end
  end
end
