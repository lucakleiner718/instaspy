class Tag < ActiveRecord::Base

  has_and_belongs_to_many :media, class_name: 'Media'

  scope :observed, -> { joins(:observed_tag).where('observed_tags.id is not null') }
  scope :chartable, -> { observed.where('observed_tags.for_chart = ?', true) }
  scope :exportable, -> { observed.where('observed_tags.export_csv = ?', true) }

  has_one :observed_tag, dependent: :destroy

  CHART_DAYS = 14

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
    Media.recent_media
  end

  def recent_media *args
    options = args.extract_options!

    client = InstaClient.new.client

    @media_list = client.tag_recent_media(self.name, min_tag_id: options[:min_id], max_tag_id: options[:max_id], count: 1000)

    @media_list.data.each do |media_item|
      media = Media.where(insta_id: media_item['id']).first_or_initialize

      user = User.where(insta_id: media_item['user']['id']).first_or_initialize
      if user.new_record?
        user2 = User.where(username: media_item['user']['username']).first_or_initialize
        unless user2.new_record?
          user = user2
          user.insta_id = media_item['user']['id']
        end
      end
      user.username = media_item['user']['username']
      user.full_name = media_item['user']['full_name']
      user.save

      media.user_id = user.id
      media.created_time = Time.at media_item['created_time'].to_i

      tags = []
      media_item['tags'].each do |tag_name|
        tags << Tag.where(name: tag_name).first_or_create
      end
      media.tags = tags

      media.save
    end
  end

  def update_info!
    client = InstaClient.new.client
    data = client.tag self.name
    # self.media_count = data['media_count']
    self.save
  end

  def chart_data amount_of_days=14
    blank = {}

    amount_of_days = amount_of_days.to_i

    amount_of_days.times do |i|
      d = amount_of_days-i
      cat = d.days.ago.utc.strftime('%m/%d')
      blank[cat] = 0
    end

    data = blank.dup

    amount_of_days.times do |i|
      day = (amount_of_days-i).days.ago.utc
      data[day.strftime('%m/%d')] =
        self.media.where('created_time >= ?', day.beginning_of_day).where('created_time <= ?', day.end_of_day).size
    end

    data.reject{|k| !k.in?(blank) }.values
  end

  def self.add_to_csv tag_name
    t = Tag.where(name: tag_name).first_or_create
    ot = t.observed_tag.present? ? t.observed_tag : t.build_observed_tag
    ot.export_csv = true
    ot.save
  end

  def self.remove_from_csv tag_name
    t = Tag.where(name: tag_name).first_or_initialize
    if t.observed_tag.present?
      t.observed_tag.update_column :export_csv, false
    end
  end

  def self.observe tag_name
    t = Tag.where(name: tag_name).first_or_create
    ot = t.observed_tag.present? ? t.observed_tag : t.build_observed_tag
    ot.save
  end

end
