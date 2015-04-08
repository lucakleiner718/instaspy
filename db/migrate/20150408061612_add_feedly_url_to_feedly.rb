class AddFeedlyUrlToFeedly < ActiveRecord::Migration
  def change
    add_column :feedly, :feedly_url, :string
  end
end
