class Feedly < ActiveRecord::Base

  self.table_name = :feedly

  def self.process url
    record = Feedly.where(website: url).first

    return record if record && record.grabbed_at && record.grabbed_at > 3.days.ago

    unless record
      record = Feedly.new
    end

    client = Feedlr::Client.new
    resp = client.search_feeds url

    if resp['results'].size > 0
      result = resp['results'].first

      exists_feed = Feedly.where(feed_id: result['feedId']).first
      record = exists_feed if exists_feed.present?

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

end
