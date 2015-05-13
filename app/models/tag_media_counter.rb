class TagMediaCounter

  include Mongoid::Document
  field :tag_id, type: String
  field :media_count, type: Integer, default: 0
  include Mongoid::Timestamps::Updated

  index({ tag_id: 1 }, { drop_dups: true })

  def self.get tag_id
    self.find_or_initialize_by(tag_id: tag_id)
  end

  def self.want tag_id
    self.find_or_create_by(tag_id: tag_id)
  end

  def update_media_count!
    return false if self.updated_at && self.updated_at > 1.week.ago
    self.update_attribute :media_count, MediaTag.where(tag_id: self.tag_id).size
  end

end
