class CreateTagStats < ActiveRecord::Migration
  def change
    create_table :tag_stats do |t|
      t.integer :tag_id
      t.integer :amount
      t.date :date
    end
  end
end
