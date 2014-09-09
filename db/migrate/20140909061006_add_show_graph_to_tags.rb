class AddShowGraphToTags < ActiveRecord::Migration
  def change
    add_column :tags, :show_graph, :boolean, default: false
  end
end
