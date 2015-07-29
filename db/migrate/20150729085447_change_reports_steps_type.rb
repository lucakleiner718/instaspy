class ChangeReportsStepsType < ActiveRecord::Migration
  def up
    remove_column :reports, :steps
    add_column :reports, :steps, :json, default: []
  end

  def down
    remove_column :reports, :steps
    add_column :reports, :steps, :text, default: [], array: true
  end
end
