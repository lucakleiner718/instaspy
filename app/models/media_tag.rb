class MediaTag  < ActiveRecord::Base

  belongs_to :tag
  belongs_to :media, class_name: 'Media'

end
