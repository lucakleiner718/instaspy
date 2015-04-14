class AddNotifyEmailToReports < ActiveRecord::Migration
  def change
    add_column :reports, :notify_email, :string
  end
end
