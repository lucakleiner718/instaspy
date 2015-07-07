class CreateMediaAmountStats < ActiveRecord::Migration
  def change
    create_table :media_amount_stats do |t|
      t.date :date
      t.integer :amount
      t.string :action
      t.datetime :updated_at
    end

    add_index :media_amount_stats, [:date, :action]
  end
end
