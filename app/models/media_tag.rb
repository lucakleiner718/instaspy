class MediaTag

  include Mongoid::Document
  belongs_to :tag
  belongs_to :media, class_name: 'Media'

  index media_id: 1
  index tag_id: 1
  index({ tag_id: 1, media_id: 1 }, { drop_dups: true })

end