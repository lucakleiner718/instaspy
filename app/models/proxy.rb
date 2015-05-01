class Proxy

  include Mongoid::Document

  field :url, type: String
  field :login, type: String
  field :password, type: String
  field :active, type: Boolean, default: true
  field :provider, type: String
  include Mongoid::Timestamps

  def self.get_some
    self.where(active: true).limit(30).sample
  end

  def to_s
    "#{self.login && self.password ? "#{self.login}:#{self.password}@" : ''}#{self.url}"
  end

end
