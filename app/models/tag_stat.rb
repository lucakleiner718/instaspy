class TagStat < ActiveRecord::Base

  include Mongoid::Document
  field :amount, type: Integer
  field :date, type: Date
  belongs_to :tag

end
