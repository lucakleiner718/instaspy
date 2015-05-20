class Import

  include Mongoid::Document

  field :file_id, type: Integer
  field :format, type: String
  field :time, type: Integer

end