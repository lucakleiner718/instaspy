class AddBatchesToReports < ActiveRecord::Migration
  def change
    add_column :reports, :batches, :json, default: {}
  end
end
