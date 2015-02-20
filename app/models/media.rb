class Media < ActiveRecord::Base

  has_and_belongs_to_many :tags
  belongs_to :user

  scope :with_location, -> { where('location_lng is not null and location_lng != ""') }
  scope :without_location, -> { where('location_lng is null or location_lng != ""').where('location_present is null') }

  reverse_geocoded_by :location_lat, :location_lng

  before_save do
    if self.location_name_changed? && self.location_name.present?
      self.location_name = self.location_name.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.location_name = self.location_name.encode(self.location_name.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.location_name.strip!
    end
  end

  after_save do
    # MediaLocationWorker.perform_async self.id if self.location_present? && self.location_lat.present? && self.location_lat_changed?
    # MediaLocationWorker.new.perform self.id if self.location_present? && self.location_lat.present? && self.location_lat_changed?
  end

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

  def location
    loc = []
    loc << self.location_country if self.location_country.present?
    loc << self.location_state if self.location_state.present?
    loc << self.location_city if self.location_city.present?
    loc.join(', ')
  end

  def update_info!
    client = InstaClient.new.client

    return false if self.user && self.user.private?

    retries = 0

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
        raise Instagram::BadRequest.new(e)
        # binding.pry
        # return false
      end
    rescue Instagram::ServiceUnavailable => e
      retries += 1
      retry if retries <= 5
      raise Instagram::ServiceUnavailable.new(e)
    # rescue Interrupt
    #   raise Interrupt
    # rescue StandardError => e
    #   # binding.pry
    #   return false
    rescue Exception => e
      # binding.pry
      return false
    end

    media_item = response.data

    self.media_user media_item['user']
    self.media_data media_item

    self.save
  end

  def media_data media_item
    if media_item['location']
      self.location_present = true
      self.location_lat = media_item['location']['latitude']
      self.location_lng = media_item['location']['longitude']
      self.location_name = media_item['location']['name']
    else
      self.location_present = false
    end

    self.likes_amount = media_item['likes']['count']
    self.comments_amount = media_item['comments']['count']
    self.link = media_item['link']
    self.created_time = Time.at media_item['created_time'].to_i

    tags = []
    media_item['tags'].each do |tag_name|
      begin
        tags << Tag.unscoped.where(name: tag_name).first_or_create
      rescue ActiveRecord::RecordNotUnique => e
        retry
      end
    end
    self.tags = tags
  end

  def media_user media_item_user
    user = User.where(insta_id: media_item_user['id']).first_or_initialize
    if user.new_record?
      # with same username as we want to create
      user2 = User.where(username: media_item_user['username']).first_or_initialize
      unless user2.new_record?
        user = user2
        user.insta_id = media_item_user['id']
      end
    end
    user.username = media_item_user['username']
    user.full_name = media_item_user['full_name']

    begin
      user.save
    rescue ActiveRecord::RecordNotUnique => e
      username = user.username
      user = User.where(username: username).first_or_create
    end

    self.user_id = user.id
  end

  def set_location
    # can add option [:lookup]
    # Geocoder::Configuration.api_key = 'd5dd99546055d0d5d6be0de04446595dd5bb365'
    # Geocoder::Configuration.lookup = :yandex

    proxy = Proxy.get_some
    if proxy
      Geocoder::Configuration.http_proxy = proxy.to_s
      # p "using proxy #{proxy.to_s}"
    end

    return false if self.location_lat.blank? || self.location_lng.blank?

    resp = Geocoder.search("#{self.location_lat},#{self.location_lng}")

    # if resp.size == 0
    #   Geocoder::Configuration.lookup = :google
    #   resp = Geocoder.search("#{self.location_lat},#{self.location_lng}")
    #   Geocoder::Configuration.lookup = :yandex
    # end

    row = resp.first
    case row.class.name
      when 'Geocoder::Result::Here'
        address = row.data['Location']['Address']
        self.location_country = Country.find_country_by_alpha3(address['Country']).name
        self.location_state = address['State']
        self.location_city = address['City']
      when 'Geocoder::Result::Google'
        row.address_components.each do |address_component|
          self.location_country = address_component['long_name'] if address_component['types'].include?('country')
          self.location_state = address_component['long_name'] if address_component['types'].include?('administrative_area_level_1')
          self.location_city = address_component['long_name'] if address_component['types'].include?('locality')
        end
      when 'Geocoder::Result::Yandex'
        address = row.data['GeoObject']['metaDataProperty']['GeocoderMetaData']['AddressDetails']

        begin
          self.location_country = address['Country']['CountryName']
        rescue
        end

        if self.location_country.blank?
          begin
            self.location_country = address['Country']['Locality']['Premise']['PremiseName']
          rescue
          end
        end

        begin
          self.location_state = address['Country']['AdministrativeArea']['AdministrativeAreaName']
        rescue Exception => e
          # binding.pry
        end

        if self.location_state.blank?
          begin
            self.location_state = address['Country']['Thoroughfare']['ThoroughfareName']
          rescue Exception => e
            # binding.pry
          end
        end

        begin
          self.location_city = address['Country']['AdministrativeArea']['Locality']['DependentLocality']['DependentLocalityName']
        rescue Exception => e
        end

        if self.location_city.blank?
          begin
            self.location_city = address['Country']['Locality']['LocalityName']
          rescue Exception => e
          end
        end

        if self.location_city.blank?
          begin
            self.location_city = address['Country']['AdministrativeArea']['SubAdministrativeArea']['SubAdministrativeAreaName']
          rescue Exception => e
          end
        end

      when 'Geocoder::Result::Esri'
        address = row.data['address']
        self.location_country = Country.find_country_by_alpha3(address['CountryCode']).alpha2
        self.location_state = address['Region']
        self.location_city = address['City']

      when 'Geocoder::Result::Bing'
        address =  row.data['address']
        country = address['countryRegion']
        country = 'KR' if country == 'South Korea'
        country_lookup = Country.find_country_by_name(country)

        self.location_country = country_lookup ? country_lookup.alpha2 : country
        self.location_state = address['adminDistrict']
        self.location_city = address['locality']
    end
  end

  def update_location!
    self.set_location
    self.save
  end

  def self.get_by_location lat, lng, *args
    options = args.extract_options!

    min_timestamp = nil
    max_timestamp = nil

    total_added = 0
    options[:total_limit] ||= 2_000
    options[:distance] ||= 100

    while true
      client = InstaClient.new.client

      begin
        client = InstaClient.new.client
        media_list = client.media_search(lat, lng, distance: options[:distance], min_timestamp: min_timestamp, max_timestamp: max_timestamp, count: 100)
      rescue JSON::ParserError, Instagram::ServiceUnavailable, Instagram::BadGateway, Instagram::InternalServerError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError => e
        p 'issue'
        break
      rescue Interrupt
        raise Interrupt
      end

      added = 0
      avg_created_time = 0
      added_media = []

      media_list.data.each do |media_item|
        media = Media.where(insta_id: media_item['id']).first_or_initialize

        media.media_user media_item['user']
        media.media_data media_item

        if media.new_record?
          added += 1
          added_media << media
        end

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

      if options[:without_location].blank?
        added_media.each { |media| media.update_location! }
      end

      if options[:created_from].present? && Time.at(avg_created_time) > options[:created_from]
        max_timestamp = media_list.data.last.created_time
      elsif options[:ignore_added] || added.to_f / media_list.data.size > 0.9
        max_timestamp = media_list.data.last.created_time
      elsif total_added >= options[:total_limit]
        break
      else
        break
      end
    end
  end

end