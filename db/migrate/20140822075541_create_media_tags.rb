class CreateMediaTags < ActiveRecord::Migration
  def change
    create_table :media_tags, id: false do |t|
      t.belongs_to :media, index: true
      t.belongs_to :tag, index: true
    end
  end
end
