class Stat
  include Mongoid::Document

  field :key, type: String
  field :value, type: String
  field :created_at, type: DateTime
  field :updated_at, type: DateTime

end