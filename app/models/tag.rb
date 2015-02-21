class Tag < ActiveRecord::Base

  has_and_belongs_to_many :media, class_name: 'Media'

  scope :observed, -> { joins(:observed_tag).where('observed_tags.id is not null') }
  scope :chartable, -> { observed.where('observed_tags.for_chart = ?', true) }
  scope :exportable, -> { observed.where('observed_tags.export_csv = ?', true) }

  default_scope -> { }

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

  # @depricated
  def self.recent_media
    Media.recent_media
  end

  def recent_media *args
    options = args.extract_options!

    min_tag_id = nil
    max_tag_id = nil

    total_added = 0
    options[:total_limit] ||= 2_000

    while true
      client = InstaClient.new.client

      begin
        media_list = client.tag_recent_media(URI.escape(self.name), min_tag_id: min_tag_id, max_tag_id: max_tag_id, count: 100)
      rescue JSON::ParserError, Instagram::ServiceUnavailable, Instagram::BadGateway, Instagram::InternalServerError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError => e
        p 'issue'
        break
      rescue Interrupt
        raise Interrupt
      end

      added = 0
      avg_created_time = 0

      media_list.data.each do |media_item|
        media = Media.where(insta_id: media_item['id']).first_or_initialize

        media.media_user media_item['user']
        media.media_data media_item

        added += 1 if media.new_record?

        begin
          media.save unless media.new_record? && Media.where(insta_id: media_item['id']).size == 1
        rescue ActiveRecord::RecordNotUnique => e
        end

        avg_created_time += media['created_time'].to_i
      end

      total_added += added

      break if media_list.data.size == 0

      avg_created_time = avg_created_time / media_list.data.size

      p "#{avg_created_time} / #{Time.at avg_created_time}"
      p "added: #{added}"
      # sleep 2

      move_next = false

      if options[:created_from].present?
        if Time.at(avg_created_time) > options[:created_from]
          # max_tag_id = media_list.pagination.next_max_tag_id
          move_next = true
        # else
        #   break
        end
      elsif options[:ignore_added] || added.to_f / media_list.data.size > 0.9
        # max_tag_id = media_list.pagination.next_max_tag_id
        move_next = true
      # elsif total_added >= options[:total_limit]
      #   break
      # else
      #   break
      end

      break unless move_next
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

  def self.get tag_name
    Tag.where(name: tag_name).first_or_create
  end

end
