class Tag < ActiveRecord::Base

  has_and_belongs_to_many :media, class_name: 'Media'

  scope :observed, -> { where observed: true }

  def users limit=1000
    self.media.limit(limit).map{|media_item| media_item.user}.uniq
  end

  def oldest_media
    self.media.order('created_time asc').first
  end

  def newest_media
    self.media.order('created_time asc').first
  end

  def get_old_media
    self.recent_media max_id: self.oldest_media.insta_id
  end

  def self.get_new_media
    Tag.observed.each do |tag|
      tag.get_new_media
    end
  end

  def get_new_media
    self.recent_media max_id: self.newest_media.insta_id
  end

  def self.recent_media
    Tag.observed.each do |tag|
      tag.recent_media
    end
  end

  def recent_media *args
    options = args.extract_options!

    client = Instagram.client(:access_token => Setting.g('instagram_access_token'))

    @media_list = client.tag_recent_media(self.name, min_tag_id: options[:min_id], max_tag_id: options[:max_id], count: 1000)

    @media_list.data.each do |media_item|
      media = Media.where(insta_id: media_item['id']).first_or_initialize

      user = User.where(insta_id: media_item['user']['id']).first_or_initialize
      user.username = media_item['user']['username']
      # user.profile_picture = media_item['user']['profile_picture']
      user.full_name = media_item['user']['full_name']
      user.save

      media.user_id = user.id
      # media.likes_amount = media_item['likes']['count']
      media.created_time = Time.at media_item['created_time'].to_i
      media.filter = media_item['filter']
      media.insta_type = media_item['type']

      tags = []
      media_item['tags'].each do |tag_name|
        tags << Tag.where(name: tag_name).first_or_create
      end
      media.tags = tags

      media.save
    end
  end

  def update_info!
    client = Instagram.client(:access_token => Setting.g('instagram_access_token'))
    data = client.tag self.name
    self.media_count = data['media_count']
    self.save
  end

end
