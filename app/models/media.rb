class Media < ActiveRecord::Base

  has_and_belongs_to_many :tags
  belongs_to :user

  def self.recent_media
    Tag.observed.each do |tag|
      tag.recent_media
    end
  end

end
