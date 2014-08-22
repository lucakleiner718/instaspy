class Setting < ActiveRecord::Base

  def self.s k, v
    row = self.where(key: k).first_or_initialize
    row.value = v
    row.save
  end

  def self.g k
    self.where(key: k).first_or_initialize.value
  end

end
