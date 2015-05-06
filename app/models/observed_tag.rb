class ObservedTag

  include Mongoid::Document
  belongs_to :tag
  field :media_updated_at, type: DateTime

end
