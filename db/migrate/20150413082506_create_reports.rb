class CreateReports < ActiveRecord::Migration
  def change
    create_table :reports do |t|
      t.string :format
      t.text :input_data
      t.string :status, default: 'new', null: false
      t.integer :progress, size: 3, default: 0
      t.text :jobs
      t.datetime :started_at
      t.datetime :finished_at
      t.string :result_data

      t.timestamps
    end
  end
end
