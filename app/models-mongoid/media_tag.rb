class MediaTag

  include Mongoid::Document
  # field :tag_id, type: String
  belongs_to :tag
  # field :media_id, type: String
  belongs_to :media, class_name: 'Media'

  index media_id: 1
  index tag_id: 1
  index media_id: 1, tag_id: 1

  # def tag
  #   Tag.find(self.tag_id)
  # end

end