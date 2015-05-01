class Feedly

  include Mongoid::Document
  field :website, type: String
  field :feed_id, type: String
  field :feedly_url, type: String
  field :subscribers_amount, type: Integer
  field :grabbed_at, type: DateTime
  include Mongoid::Timestamps

  index feed_id: 1

  belongs_to :user

  # validates :website, uniqueness: true, presence: true
  # validates :feedly_url, uniqueness: true

  def self.process url
    record = Feedly.where(website: url).first

    return record if record && record.grabbed_at && record.grabbed_at > 3.days.ago

    unless record
      record = Feedly.new
    end

    client = Feedlr::Client.new

    retries = 0
    begin
      resp = client.search_feeds url
    rescue Feedlr::Error, Feedlr::Error::RequestTimeout => e
      retries += 1
      sleep 10*retries
      retry if retries <= 5
      raise e
    end

    if resp['results'] && resp['results'].size > 0
      result = resp['results'].first

      exists_feed = Feedly.where(feed_id: result['feedId']).first
      record = exists_feed if exists_feed.present?

      record.feedly_url = result['website']
      record.website = url
      record.feed_id = result['feedId']
      record.subscribers_amount = result['subscribers'] || 0

      record.grabbed_at = Time.now
      record.save

      record
    else
      false
    end
  end

  def update_info!
    return true if self.grabbed_at.present? && self.grabbed_at > 3.weeks.ago

    url = self.feedly_url || self.website
    client = Feedlr::Client.new
    resp = client.search_feeds url

    if resp['results'].size > 0
      result = resp['results'].first

      self.feedly_url = result['website']
      self.website = self.website
      self.feed_id = result['feedId']
      self.subscribers_amount = result['subscribers'] || 0

      self.grabbed_at = Time.now
      self.save
      true
    else
      false
    end
  end

end
