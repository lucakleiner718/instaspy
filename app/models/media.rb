class Media < ActiveRecord::Base

  has_and_belongs_to_many :tags
  belongs_to :user

  def self.recent_media
    tag = Tag.observed.where('observed_tags.media_updated_at < ? or observed_tags.media_updated_at is null', 1.minute.ago).order('observed_tags.media_updated_at asc').first
    if tag.present?
      tag.observed_tag.update_column :media_updated_at, Time.now
      tag.recent_media
    end
  end

  def self.report starts=nil, ends=nil
    Reporter.media_report starts, ends
  end

  # delete all media oldest than 12 weeks
  def self.delete_old frame=12.weeks
    Media.where('created_time < ?', frame.ago).destroy_all
  end

  def update_info!
    client = InstaClient.new.client

    return false if self.user.private?

    begin
      response = client.media_item(self.insta_id)
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error('Faraday::ConnectionFailed')
      return false
    rescue Instagram::BadRequest => e
      if e.message =~ /invalid media id/
        self.destroy
        return false
      elsif e.message =~ /you cannot view this resource/
        self.user.update_info!
        return false
      else
        binding.pry
        return false
      end
    rescue Interrupt
      raise Interrupt
    rescue StandardError => e
      binding.pry
      return false
    rescue Exception => e
      binding.pry
      return false
    end

    media_item = response.data

    user = User.where(insta_id: media_item['user']['id']).first_or_initialize
    if user.new_record?
      # with same username as we want to create
      user2 = User.where(username: media_item['user']['username']).first_or_initialize
      unless user2.new_record?
        user = user2
        user.insta_id = media_item['user']['id']
      end
    end
    user.username = media_item['user']['username']
    user.full_name = media_item['user']['full_name']
    user.save
    self.user_id = user.id

    self.likes_amount = media_item['likes']['count']
    self.comments_amount = media_item['comments']['count']
    self.link = media_item['link']
    self.created_time = Time.at media_item['created_time'].to_i

    tags = []
    media_item['tags'].each do |tag_name|
      tags << Tag.unscoped.where(name: tag_name).first_or_create
    end
    self.tags = tags

    self.save
  end

end
