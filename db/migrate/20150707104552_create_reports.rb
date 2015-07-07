class CreateReports < ActiveRecord::Migration
  def change
    create_table :reports do |t|
      t.string :format
      t.string :original_input
      t.string :processed_input
      t.string :status
      t.integer :progress, default: 0
      t.json :jobs, default: {}
      t.datetime :started_at
      t.datetime :finished_at
      t.string :result_data
      t.string :notify_email
      t.text :output_data, array: true, defualt: []
      t.text :not_processed, array: true, defualt: []
      t.text :steps, array: true, defualt: []
      t.datetime :date_from
      t.datetime :date_to
      t.json :data, default: {}
      t.text :tmp_list1, array: true, default: []
      t.string :note
      t.json :amounts, default: {}

      t.timestamps null: false
    end
  end
end
