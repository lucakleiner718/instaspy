class Proxy < ActiveRecord::Base

  def self.get_some
    self.where(active: true).limit(30).sample
  end

  def to_s
    "#{self.login && self.password ? "#{self.login}:#{self.password}@" : ''}#{self.url}"
  end

end
