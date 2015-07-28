class ChangeDateRangeForReports < ActiveRecord::Migration
  def change
    change_column :reports, :date_from, :date
    change_column :reports, :date_to, :date
  end
end
