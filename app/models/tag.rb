class Tag

  include Mongoid::Document
  field :name, type: String

  index({ name: 1 }, { drop_dups: true, background: true })

  # has_many :media_tags#, class_name: 'Media'#, after_add: :increment_some_tag, after_remove: :decrement_some_tag

  scope :observed, -> { where(:id.in => ObservedTag.all.pluck(:tag_id)) }
  scope :chartable, -> { where(:id.in => ObservedTag.where(for_chart: true).pluck(:tag_id)) }
  scope :exportable, -> { where(:id.in => ObservedTag.where(export_csv: true).pluck(:tag_id)) }

  has_one :observed_tag, dependent: :destroy

  validates :name, format: { with: /\A[^\.\-\/\(\)\*\^\%\$\#\@\!,\?\}\]\{\[\;\:\"\'\>\<]+\z/ }

  CHART_DAYS = 14

  def name=(value)
    if value.present?
      value = value.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      value = value.encode(value.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      value.strip!
      value = value[0, 255]
    end

    # this is same as self[:attribute_name] = value
    write_attribute(:name, value)
  end

  # offset (DateTime) - start point of user grabbing
  # total_limit (integer) - amount of media, stop grabbing when code receive provided amount
  # created_from (DateTime) - last point, until code should grab data
  def recent_media *args
    options = args.extract_options!

    max_tag_id = nil

    if options[:offset].present?
      m = Media.where(:created_time.gte => options[:offset]).and(:created_time.lte => (options[:offset] + 10.minutes)).order(created_time: :asc).first
      unless m
        m = Media.where(:created_time.gte => options[:offset]).and(:created_time.lte => (options[:offset] + 60.minutes)).order(created_time: :asc).first
      end
      if m
        max_tag_id = m.insta_id.match(/^(\d+)_/)[1]
      end
    end

    total_added = 0
    total_processed = 0
    options[:total_limit] ||= 5_000
    start_media_amount = self.media.length if options[:media_atleast]
    created_time_list = []
    tags_found = []

    while true
      time_start = Time.now

      retries = 0
      begin
        client = InstaClient.new.client
        media_list = client.tag_recent_media(URI.escape(self.name), max_tag_id: max_tag_id, count: 100)
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::BadRequest,
        Instagram::InternalServerError, Instagram::GatewayTimeout, Instagram::InternalServerError,
        JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE, Errno::EOPNOTSUPP => e
        Rails.logger.debug e
        retries += 1
        sleep 5*retries
        retry if retries <= 6
        raise e
      end

      ig_time_end = Time.now

      added = 0

      data = media_list.data

      media_found = Media.in(insta_id: data.map{|el| el['id']}).to_a
      tags_found.concat(Tag.in(name: data.map{|el| el['tags']}.flatten.uniq).to_a).uniq!
      users_found = User.in(insta_id: data.map{|el| el['user']['id']}.uniq).to_a

      data.each do |media_item|
        logger.debug "#{">>".green} Start process #{media_item['id']}"
        st_time = Time.now
        media = media_found.select{|el| el.insta_id == media_item['id']}.first
        unless media
          media = Media.new(insta_id: media_item['id'])
          added += 1
        end

        media.set_user media_item['user'], users_found
        media.set_data media_item

        media.save

        media.set_tags media_item['tags'], tags_found

        tags_found.concat(media.tags).uniq!

        created_time_list << media['created_time'].to_i
        logger.debug "#{">>".green} End process #{media_item['id']}. Time: #{(Time.now - st_time).to_f.round(2)}s"
      end

      tags_found = []

      total_added += added
      total_processed += media_list.data.size

      break if media_list.data.size == 0

      created_time_list = created_time_list.sort
      median_created_time = created_time_list.size % 2 == 0 ? (created_time_list[(created_time_list.size/2-1)..(created_time_list.size/2+1)].sum / 3) : (created_time_list[(created_time_list.size/2)..(created_time_list.size/2+1)].sum / 2)

      time_end = Time.now
      logger.debug "#{">>".green} [#{self.name.green}] / #{media_list.data.size}/#{total_processed} #{added.to_s.cyan}/#{total_added.to_s.cyan} / MT: #{((Time.at median_created_time).strftime('%d/%m/%y %H:%M:%S')).to_s.yellow} / IG: #{(ig_time_end-time_start).to_f.round(2)}s / T: #{(time_end - time_start).to_f.round(2)}s"

      move_next = false

      if options[:created_from].present?
        if Time.at(median_created_time) > options[:created_from]
          move_next = true
        end
      elsif options[:total_limit] && total_added > options[:total_limit]
        logger.debug "#{total_added.to_s.blue} total added is over limit #{options[:total_limit].to_s.red}"
        # stopping
      elsif options[:ignore_exists]
        move_next = true
      # if amount of currently added is over 30% of grabbed from instagram
      elsif added.to_f / media_list.data.size > 0.3
        move_next = true
      end

      if options[:media_atleast] && start_media_amount+total_added < options[:media_atleast]
        move_next = true
      end

      break unless move_next

      max_tag_id = media_list.pagination.next_max_tag_id

      # stop if we don't have next page
      break unless max_tag_id
    end
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
    t.update_media_count!
  end

  def self.remove_from_csv tag_name
    t = Tag.where(name: tag_name).first_or_initialize
    if t.observed_tag.present?
      t.observed_tag.update_attribute :export_csv, false
    end
  end

  def self.observe tag_name
    t = Tag.where(name: tag_name).first_or_create
    ot = t.observed_tag.present? ? t.observed_tag : t.build_observed_tag
    ot.save
    t.update_media_count!
  end

  def self.get tag_name
    Tag.where(name: tag_name).first_or_create
  end

  def publishers
    ids = self.media.pluck('distinct user_id')
    User.where(id: ids)
  end

  def count_media
    MediaTag.where(tag_id: self.id).size
  end

  def update_media_count!
    amount = self.count_media
    tmc = TagMediaCounter.get(self.id)
    tmc.media_count = amount
    tmc.save
  end

  def self.increment_counter tag_id
    TagMediaCounter.want(tag_id).inc(media_count: 1)
  end

  def self.decrement_counter tag_id
    TagMediaCounter.want(tag_id).inc(media_count: -1)
  end

  def media_count
    TagMediaCounter.get(self.id).media_count
  end

  def self.count_media tag_id
    MediaTag.where(tag_id: tag_id).size
  end

  def self.update_media_count! tag_id
    amount = self.count_media tag_id
    tmc = TagMediaCounter.get(tag_id)
    tmc.media_count = amount
    tmc.save
  end

  def media
    Media.in(id: MediaTag.where(tag_id: self.id).pluck(:media_id))
  end

end
