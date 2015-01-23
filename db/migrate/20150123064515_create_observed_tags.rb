class CreateObservedTags < ActiveRecord::Migration
  def up
    create_table :observed_tags do |t|
      t.integer :tag_id
      t.boolean :export_csv, default: false
      t.boolean :for_chart, default: false
      t.datetime :media_updated_at

      t.timestamps
    end

    Tag.where(observed: true).each do |t|
      ObservedTag.create tag_id: t.id, export_csv: t.grabs_users_csv, for_chart: t.show_graph
    end

    remove_column :tags, :observed
    remove_column :tags, :grabs_users_csv
    remove_column :tags, :show_graph
    remove_column :tags, :updated_at
  end

  def down
    add_column :tags, :observed, :boolean, default: false
    add_column :tags, :grabs_users_csv, :boolean, default: false
    add_column :tags, :show_graph, :boolean, default: false
    add_column :tags, :updated_at, :datetime

    ObservedTag.all.each do |observed_tag|
      observed_tag.tag.update_columns observed: true, grabs_users_csv: observed_tag.export_csv, show_graph: observed_tag.for_chart
    end

    drop_table :observed_tags
  end
end
