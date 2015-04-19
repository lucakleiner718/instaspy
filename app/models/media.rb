class Media < ActiveRecord::Base

  has_and_belongs_to_many :tags, after_add: :increment_some_tag, after_remove: :decrement_some_tag
  belongs_to :user

  scope :with_location, -> { where('location_lat is not null and location_lat != ""') }
  scope :without_location, -> { where('location_lat is null or location_lat != ""').where('location_present is null') }

  reverse_geocoded_by :location_lat, :location_lng

  def location_name=(value)
    if value.present?
      value = value.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      value = value.encode(value.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      value.strip!
      value = value[0, 255]
    end

    # this is same as self[:attribute_name] = value
    write_attribute(:location_name, value)
  end

  def location
    loc = []
    loc << self.location_country if self.location_country.present?
    loc << self.location_state if self.location_state.present?
    loc << self.location_city if self.location_city.present?
    loc.join(', ')
  end

  def update_info!
    return false if self.user && self.user.private?

    retries = 0

    begin
      client = InstaClient.new.client
      response = client.media_item(self.insta_id)
    rescue Instagram::BadRequest => e
      if e.message =~ /invalid media id/
        self.destroy
        return false
      elsif e.message =~ /you cannot view this resource/
        self.user.update_info! force: true
        return false
      else
        raise e
      end
    rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::BadRequest,
      Instagram::InternalServerError,
      JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
      sleep 10
      retries += 1
      retry if retries <= 5
      raise e
    end

    self.media_user response.data['user']
    self.media_data response.data
    self.media_tags response.data['tags'], self.tags.to_a
    self.updated_at = Time.now

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
  end

  def media_user media_item_user, users_found=nil
    user = nil
    user = users_found.select{|el| el.insta_id == media_item_user['id'].to_i}.first if users_found.present?
    user = User.where(insta_id: media_item_user['id']).first_or_initialize unless user
    # if user.new_record?
    #   # with same username as we want to create
    #   user2 = User.where(username: media_item_user['username']).first_or_initialize
    #   unless user2.new_record?
    #     user = user2
    #     user.insta_id = media_item_user['id']
    #   end
    # end
    user.username = media_item_user['username']
    user.full_name = media_item_user['full_name']

    begin
      user.save
    rescue ActiveRecord::RecordNotUnique => e
      if e.message =~ /Duplicate entry/ && e.message =~ /index_users_on_username/
        exists_user = User.where(username: user.username).first
        if exists_user.insta_id == user.insta_id
          user = exists_user
        else
          exists_user.update_info!
          if exists_user.private? || exists_user.username == user.username
            exists_user.destroy
            retry
          end
        end
      else
        user = User.where(username: user.username).first
      end
    end

    self.user_id = user.id
  end

  def media_tags tags_list, tags_found=nil
    tags_to_create = tags_list
    if tags_found && tags_found.class.name == 'Array' && tags_found.size > 0
      tags_to_create = tags_to_create.map{|tname| tname.downcase} - tags_found.map{|t| t.name.downcase}
    end

    if tags_to_create.size > 0
      Tag.connection.execute("INSERT IGNORE INTO tags (name) VALUES #{tags_to_create.map{|t_name| "(#{Tag.connection.quote t_name})"}.join(',')}")
    end
    tags_ids = Tag.where(name: tags_list).pluck(:id)

    current_tags_ids = Tag.connection.execute("SELECT tag_id FROM media_tags WHERE media_id=#{self.id}").to_a.map(&:first).uniq
    # deleted_tags = current_tags_ids - new_tags_ids
    added_tags = tags_ids - current_tags_ids

    # if deleted_tags.size > 0
    #   Tag.connection.execute("DELETE FROM media_tags WHERE media_id=#{self.id} AND tag_id IN(#{deleted_tags.join(',')})")
    #   Tag.connection.execute("UPDATE tags SET media_count=media_count-1 WHERE id in (#{deleted_tags.join(',')})")
    # end
    if added_tags.size > 0
      begin
        Media.connection.execute("INSERT IGNORE INTO media_tags (media_id, tag_id) VALUES #{tags_ids.map{|tid| "(#{media_id}, #{tid})"}.join(',')}")
        Media.connection.execute("UPDATE tags SET media_count=media_count+1 WHERE id in (#{tags_ids.join(',')})")
      rescue Mysql2::Error => e
        if e =~ /Lock wait timeout exceeded/
          UpdateTagMediaCounterWorker.perform_async self.id, added_tags
        else
          raise e
        end
      end
      # Media.connection.execute("INSERT IGNORE INTO media_tags (media_id, tag_id) VALUES #{added_tags.map{|tid| "(#{self.id}, #{tid})"}.join(',')}")
      # Media.connection.execute("UPDATE tags SET media_count=media_count+1 WHERE id in (#{added_tags.join(',')})")
    end
  end

  # def media_tags2 tags_names, tags_found=nil
  #   unless tags_found
  #     tags_found = self.tags
  #   end
  #
  #   find_more = media_item['tags']
  #   if tags_found.size > 0
  #     find_more -= tags_found.map{|el| el.name.downcase}
  #   end
  #
  #   if find_more.size > 0
  #     tags_found.concat Tag.where(name: find_more).to_a
  #   end
  #
  #   tags_list = []
  #   tags_names.each do |tag_name|
  #     tag = nil
  #     if tags_found
  #       tag = tags_found.select{|el| el.name.downcase == tag_name.downcase}.first
  #     end
  #     unless tag
  #       begin
  #         # if tags_found
  #         #   tag = Tag.unscoped.where(name: tag_name).create
  #         # else
  #         tag = Tag.unscoped.where(name: tag_name).first_or_create
  #           # end
  #       rescue ActiveRecord::RecordNotUnique => e
  #         # Rails.logger.info "#{"Duplicated entry #{tag_name}".red} / #{tags_found.map{|el| el.name}.join(',')}"
  #         tag = Tag.unscoped.where(name: tag_name).first
  #       end
  #     end
  #     tags_list << tag if tag && tag.valid?
  #   end
  #
  #   self.tags = tags_list.uniq{|el| el.id}
  # end


  def set_location *args
    options = args.extract_options!

    # proxy = Proxy.get_some
    # if proxy
    #   Geocoder::Configuration.http_proxy = proxy.to_s
    #   logger.debug "using proxy #{proxy.to_s}"
    # end

    return false if self.location_lat.blank? || self.location_lng.blank?

    lookup_list = [:bing, :google, :yandex, :esri, :here]

    while true
      retries = 0
      begin
        default_lookup = Geocoder::Configuration.lookup

        lookup = options[:lookup] ? options[:lookup] : lookup_list.sample

        time_start = Time.now
        resp = Geocoder.search("#{self.location_lat},#{self.location_lng}", lookup: lookup)
        logger.info "Geocoder search for coords with lookup: #{lookup.to_s.cyan}. default: #{default_lookup.to_s.black.on_white}. Media id: #{self.id}. Time: #{(Time.now - time_start).to_f.round(2)}s"
      rescue TimeoutError, SocketError, Geocoder::ResponseParseError,
             Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Zlib::BufError, Zlib::DataError => e
        logger.info "Geocoder exception #{e.class.name}::#{e.message}".light_red
        sleep 10
        retries += 1
        retry if retries <= 5
        return false
      rescue Geocoder::InvalidRequest => e
        return false
      rescue Geocoder::OverQueryLimitError => e
        lookup_list = lookup_list - [lookup]
        retry
      end

      break if resp.first

      lookup_list = lookup_list - [lookup]

      break if lookup_list.size == 0
    end

    row = resp.first
    case row.class.name
      when 'Geocoder::Result::Here'
        address = row.data['Location']['Address']
        c = Country.find_country_by_alpha3(address['Country'])
        self.location_country = c ? c.alpha2 : address['Country']
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
          self.location_country = Country.find_country_by_name(address['Country']['CountryName']).alpha2
        rescue
        end

        if self.location_country.blank?
          begin
            self.location_country = Country.find_country_by_name(address['Country']['Locality']['Premise']['PremiseName']).alpha2
          rescue
          end
        end

        begin
          self.location_state = address['Country']['AdministrativeArea']['AdministrativeAreaName']
        rescue => e
          # binding.pry
        end

        if self.location_state.blank?
          begin
            self.location_state = address['Country']['Thoroughfare']['ThoroughfareName']
          rescue => e
            # binding.pry
          end
        end

        begin
          self.location_city = address['Country']['AdministrativeArea']['Locality']['DependentLocality']['DependentLocalityName']
        rescue => e
        end

        if self.location_city.blank?
          begin
            self.location_city = address['Country']['Locality']['LocalityName']
          rescue => e
          end
        end

        if self.location_city.blank?
          begin
            self.location_city = address['Country']['AdministrativeArea']['SubAdministrativeArea']['SubAdministrativeAreaName']
          rescue => e
          end
        end

      when 'Geocoder::Result::Esri'
        address = row.data['address']
        c = Country.find_country_by_alpha3(address['CountryCode'])
        self.location_country = c ? c.alpha2 : address['CountryCode']
        self.location_state = address['Region']
        self.location_city = address['City']

      when 'Geocoder::Result::Bing'
        address =  row.data['address']
        country = address['countryRegion']
        country = 'KR' if country == 'South Korea'
        country_lookup = Country.find_country_by_name(country)

        self.location_country = country_lookup ? country_lookup.alpha2 : country
        self.location_state = address['adminDistrict']
        self.location_city = address['locality'] || address['adminDistrict2']
    end
  end

  def update_location! *args
    self.set_location *args
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
      retries = 0
      begin
        client = InstaClient.new.client
        media_list = client.media_search(lat, lng, distance: options[:distance], min_timestamp: min_timestamp, max_timestamp: max_timestamp, count: 100)
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::BadRequest,
        Instagram::InternalServerError,
        JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
        sleep 10
        retries += 1
        retry if retries <= 5
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

      logger.debug "#{avg_created_time} / #{Time.at avg_created_time} / added: #{added}"

      if options[:without_location].blank?
        added_media.each { |media| media.update_location! }
      end

      if options[:created_from].present? && Time.at(avg_created_time) > options[:created_from]
        max_timestamp = media_list.data.last.created_time
      elsif options[:ignore_exists] || added.to_f / media_list.data.size > 0.1
        max_timestamp = media_list.data.last.created_time
      elsif total_added >= options[:total_limit]
        break
      else
        break
      end
    end
  end

  def self.get id
    Media.where(insta_id: id).first
  end

  def get_country
    coords = [self.location_lat, self.location_lng]
    g = RGeo::Geos::CAPIFactory.new
    point = g.point coords[1], coords[0]
    filename = 'vendor/TM_WORLD_BORDERS-0.3/TM_WORLD_BORDERS-0.3.shp'
    shapes = RGeo::Shapefile::Reader.open(filename)
    shapes.each do |shape|
      puts "#{shape.attributes['NAME']}"
      if shape.geometry.contains? point
        return shape.attributes
      end
    end
    false
  end

  private

  # after_create :increment_tag
  # after_destroy :decrement_tag

  # def increment_tag
  #   t = self.tags
  #   self.class.connection.execute("update tags set media_count=media_count+1 where id in (#{t.map(&:id).join(',')})") if t.size > 0
  # end
  #
  # def decrement_tag
  #   t = self.tags
  #   self.class.connection.execute("update tags set media_count=media_count-1 where id in (#{t.map(&:id).join(',')})") if t.size > 0
  # end

  def increment_some_tag tag
    # tag.increment! :media_count
    # Tag.transaction do
    # Tag.increment_counter :media_count, tag.id
    # end
    begin
      self.class.connection.execute("update tags set media_count=media_count+1 where id=#{tag.id}")
    rescue => e
      TagMediaCounterWorker.perform_async tag.id, '+'
    end
  end

  def decrement_some_tag tag
    # tag.decrement! :media_count
    # Tag.transaction do
    # Tag.decrement_counter :media_count, tag.id
    # end
    begin
      self.class.connection.execute("update tags set media_count=media_count-1 where id=#{tag.id}")
    rescue => e
      TagMediaCounterWorker.perform_async tag.id, '-'
    end
  end

end
