class TagMediaCounter
  include Mongoid::Document
  field :tag_id, type: Integer
  field :media_count, type: Integer, default: 0
  include Mongoid::Timestamps::Updated

  index({ tag_id: 1 }, { unique: true })

  def self.get tag_id
    self.find_or_initialize_by(tag_id: tag_id)
  end

  def self.want tag_id
    self.find_or_create_by(tag_id: tag_id)
  end

end
