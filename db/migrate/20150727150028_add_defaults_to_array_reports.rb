class AddDefaultsToArrayReports < ActiveRecord::Migration
  def up
    remove_column :reports, :output_data
    add_column :reports, :output_data, :text, array: true, default: []
    remove_column :reports, :not_processed
    add_column :reports, :not_processed, :text, array: true, default: []
    remove_column :reports, :steps
    add_column :reports, :steps, :text, array: true, default: []
  end
end
