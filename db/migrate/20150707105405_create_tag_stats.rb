class CreateTagStats < ActiveRecord::Migration
  def change
    create_table :tag_stats do |t|
      t.integer :amount
      t.date :date
      t.integer :tag_id
    end

    add_index :tag_stats, :tag_id
  end
end
