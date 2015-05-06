class ObservedTag

  include Mongoid::Document
  belongs_to :tag
  field :media_updated_at, type: DateTime
  field :export_csv, type: Boolean, default: false
  field :for_chart, type: Boolean, default: false

end
