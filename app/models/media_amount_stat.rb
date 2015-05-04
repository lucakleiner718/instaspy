class MediaAmountStat

  include Mongoid::Document

  field :date, type: Date
  field :amount, type: Integer
  field :action, type: String
  field :updated_at, type: DateTime

  index({ date: 1, action: 1 }, { drop_dups: true, background: true })

end