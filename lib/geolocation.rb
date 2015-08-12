class Geolocation

  def initialize lat, lng, media_id
    @lat = lat
    @lng = lng
    @media_id = media_id
    @lookup_list = [:bing, :google, :yandex, :esri, :nominatim] #opencagedata
    @default_lookup = Geocoder::Configuration.lookup
  end

  def get_location *args
    resp = nil
    resp = get_from_internal *args if rand(100) == 1
    resp = get_from_external *args unless resp
    resp
    get_from_external *args
  end

  protected

  def get_from_internal *args
    resp = Curl.get("http://geo.socialrootdata.com/nearest?lat=#{@lat}&lng=#{@lng}")
    json = JSON.parse resp.body_str
    # {"name":"Qars Al Sarab Desert Resort By Anantara","country_code":"AE","region_code":"01","time":0.004598645}
    {country: json['country_code'], state: json['region'], city: json['city']} if json['country_code']
  end

  def get_from_external *args
    options = args.extract_options!

    lookup_list = options[:lookup_list] || @lookup_list

    @country = @state = @city = @country_lookup = nil

    while true
      retries = 0
      begin
        lookup = options[:lookup] ? options[:lookup] : lookup_list.sample

        time_start = Time.now
        logger.info "Geocoder search for coords with lookup: #{lookup.to_s.cyan}. default: #{@default_lookup.to_s.black.on_white}. Media id: #{@media_id}. Time: #{(Time.now - time_start).to_f.round(2)}s"
        resp = Geocoder.search("#{@lat},#{@lng}", lookup: lookup)
      rescue TimeoutError, SocketError, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::ECONNRESET,
        Zlib::BufError, Zlib::DataError => e
        logger.info "Geocoder exception #{e.class.name} #{e.message}".light_red
        sleep 10
        retries += 1
        retry if retries <= 5
        return false
      rescue Geocoder::ResponseParseError => e
        logger.info "Geocoder exception #{e.class.name}::#{e.message} / #{e.try :response}".light_red
        lookup_list = lookup_list - [lookup]
        retry
      rescue Geocoder::InvalidRequest => e
        return false
      rescue Geocoder::OverQueryLimitError, Geocoder::ServiceUnavailable => e
        logger.info "Geocoder exception #{e.class.name}::#{e.message}".light_red
        lookup_list = lookup_list - [lookup]
        retry
      end

      @row = resp.first

      if @row
        method_name = "process_#{@row.class.name.downcase.match(/::(\w+)$/)[1]}".to_sym
        break
      end

      lookup_list = lookup_list - [lookup]

      break if lookup_list.size == 0

      retries += 1
      break if retries > 5
    end

    send method_name

    if @country
      @country_lookup = Country.find_country_by_name(@country) unless @country_lookup
      @country_lookup = Country.find_country_by_alpha2(@country) unless @country_lookup
      @country_lookup = Country.find_country_by_alpha3(@country) unless @country_lookup
    end

    # if @country == "US" && !@country_lookup.states[@state]
    #   st = @country_lookup.states.select{|k, v| v['name'] == @state}.first
    #   @state = st.first if st
    # end

    @country = @country_lookup.alpha2 if @country_lookup

    {country: @country, state: @state, city: @city}
  end

  def process_here
    address = @row.data['Location']['Address']
    @country_lookup = Country.find_country_by_alpha3(address['Country'])

    @country = @country_lookup ? @country_lookup.alpha2 : address['Country']
    @state = address['State']
    @city = address['City']
  end

  def process_google
    @row.address_components.each do |address_component|
      if address_component['types'].include?('country')
        @country = address_component['short_name'] || address_component['long_name']
      end
      if address_component['types'].include?('administrative_area_level_1')
        @state = address_component['short_name'] || address_component['long_name']
      end
      if address_component['types'].include?('locality')
        @city = address_component['short_name'] || address_component['long_name']
      end
    end
  end

  def process_yandex
    address = @row.data['GeoObject']['metaDataProperty']['GeocoderMetaData']['AddressDetails']

    @country = Country.find_country_by_name(address['Country']['CountryName']).alpha2 rescue nil

    if @country.blank?
      @country = Country.find_country_by_name(address['Country']['Locality']['Premise']['PremiseName']).alpha2 rescue nil
    end

    @state = address['Country']['AdministrativeArea']['AdministrativeAreaName'] rescue nil

    if @state.blank?
      @state = address['Country']['Thoroughfare']['ThoroughfareName'] rescue nil
    end

    @city = address['Country']['AdministrativeArea']['Locality']['DependentLocality']['DependentLocalityName'] rescue nil

    if @city.blank?
      @city = address['Country']['Locality']['LocalityName'] rescue nil
    end

    if @city.blank?
      @city = address['Country']['AdministrativeArea']['SubAdministrativeArea']['SubAdministrativeAreaName'] rescue nil
    end
  end

  def process_esri
    address = @row.data['address']
    if address
      @country_lookup = Country.find_country_by_alpha3(address['CountryCode'])
      @country = @country_lookup ? @country_lookup.alpha2 : address['CountryCode']
      @state = address['Region']
      @city = address['City']
    end
  end

  def process_bing
    address = @row.data['address']
    @country = address['countryRegion']
    @country = 'KR' if @country == 'South Korea'
    @country_lookup = Country.find_country_by_name(@country)

    @country = @country_lookup ? @country_lookup.alpha2 : @country
    @state = address['adminDistrict']
    @city = address['locality'] || address['adminDistrict2']
  end

  def process_nominatim
    address = @row.data['address']
    if address
      @country = address['country']
      @state = address['state']
      @city = address['city']
    end
  end

  def process_opencagedata
    address = @row.data['components']
    if address
      @country = address['country']
      @state = address['state']
      @city = address['city']
    end
  end

  def logger
    Rails.logger
  end

end