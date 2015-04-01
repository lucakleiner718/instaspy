class MediaAmountStat
  include Mongoid::Document

  field :date, type: Date
  field :amount, type: Integer
  field :updated_at, type: DateTime

  index({date: 1}, { unique: true, background: true })

end