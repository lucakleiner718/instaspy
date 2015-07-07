class CreateObservedTags < ActiveRecord::Migration
  def change
    create_table :observed_tags do |t|
      t.integer :tag_id
      t.datetime :media_updated_at
      t.boolean :export_csv, default: false
      t.boolean :for_chart, default: false
    end

    add_index :observed_tags, :tag_id, unique: true
  end
end
