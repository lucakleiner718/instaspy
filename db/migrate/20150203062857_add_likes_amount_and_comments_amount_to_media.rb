class AddLikesAmountAndCommentsAmountToMedia < ActiveRecord::Migration
  def change
    add_column :media, :likes_amount, :integer
    add_column :media, :comments_amount, :integer
    add_column :media, :link, :string
  end
end
