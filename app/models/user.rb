class User < ActiveRecord::Base

  has_many :media, class_name: 'Media', dependent: :destroy
  has_many :feedly

  has_many :user_followers, class_name: 'Follower', foreign_key: :user_id, dependent: :destroy
  has_many :followers, through: :user_followers
  has_many :user_followees, class_name: 'Follower', foreign_key: :follower_id, dependent: :destroy
  has_many :followees, through: :user_followees

  validates :insta_id, format: { with: /\A\d+\z/ }
  # validates :username, length: { maximum: 30 }#uniqueness: true, if: 'username.present?'

  scope :not_grabbed, -> { where grabbed_at: nil }
  scope :not_private, -> { where private: false }
  scope :privates, -> { where private: true }
  scope :outdated, -> (date=7.days.ago) { where("grabbed_at is null OR grabbed_at < ?", date) }
  scope :with_url, -> { where("website is not null AND website != ''") }
  scope :without_likes, -> { where("avg_likes is null OR avg_likes_updated_at is null OR avg_likes_updated_at < ?", 1.month.ago) }
  scope :without_comments, -> { where("avg_comments is null OR avg_likes_updated_at is null OR avg_likes_updated_at < ?", 1.month.ago) }
  scope :without_location, -> { where("location_updated_at is null OR location_updated_at < ?", 6.months.ago) }
  scope :with_media, -> { where("media_amount > ?", 0) }

  before_save do
    # Catch email from bio
    if self.bio_changed? && self.bio.present?
      email_regex = /([\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+)/
      m = self.bio.downcase.match(email_regex)
      if m && m[1]
        self.email = m[1].sub(/^[\.\-\_]+/, '')
      end

      self.set_location_from_bio
    end

    if self.username_changed?
      self.username = self.username.strip.downcase.gsub(/\s/, '')

      if self.insta_id.present?
        User.fix_exists_username(self.username, self.insta_id)
      end
    end

    if self.email_changed? && self.email.present?
      self.email = self.email.downcase
    end
  end

  # around_save do
  #   begin
  #     yield
  #   rescue ActiveRecord::RecordNotUnique => e
  #     if self.insta_id.present?
  #       if e.message =~ /username/
  #         # user = self.where(username: username).where("insta_id != ?", exists_insta_id).first
  #         # user.update_info! force: true if user.present?
  #       else
  #         raise e
  #       end
  #     end
  #   end
  # end

  def full_name=(value)
    value.strip! if value.present?
    write_attribute(:full_name, value)
  end

  def bio=(value)
    value.strip! if value.present?
    write_attribute(:bio, value)
  end

  def website=(value)
    value = value.strip if value.present?
    write_attribute(:website, value)
  end


  # Update user info
  #
  # @option options :force [Boolean] if false and user not outdated, user will not be updated with fresh request to IG
  #
  # @return [Boolean] if user was updated
  #
  # @note
  #   User will be update only if it is not actual (see :actual?)
  #
  def update_info! *args
    options = args.extract_options!
    return true if self.actual? && !options[:force]

    # if we know only username, but no insta id
    if self.insta_id.blank? && self.username.present?
      ic = InstaClient.new
      resp = ic.client.user_search(self.username)

      data = nil
      data = resp.data.select{|el| el['username'].downcase == self.username.downcase }.first if resp.data.size > 0

      # if returned item only one and searched username different to returned one -
      # than we know that account changed it's username
      if data.nil? && resp.data.size == 1
        d = resp.data.first
        u = User.where(username: d['username']).first
        if u
          u.update_info!
          if u.username == d['username']
            self.destroy
            return u
          end
        end
        data = d
      end

      # if we have data - update, if we don't have data, than better remove this account from database
      if data
        self.set_data data
      else
        self.destroy
        return false
      end
    end

    exists_username = nil

    return false if self.insta_id.blank?

    if self.private?
      if self.username.blank?
        self.destroy
        return false
      end

      resp = self.update_via_http!
      return false unless resp

      return !self.destroyed?
    else
      begin
        ic = InstaClient.new
        info = ic.client.user(self.insta_id)
        data = info.data

        exists_username = nil
        # if we already have in database user with same username
        if data['username'] != self.username
          exists_username = User.where(username: data['username']).first
          if exists_username
            # set random username for it, later we will start update_info to get actual username
            exists_username.username = "#{exists_username.username}#{Time.now.to_i}"
            exists_username.save!
          end
        end
      rescue Instagram::BadRequest => e
        if e.message =~ /you cannot view this resource/

          # if user is private and we don't have it's username, than just remove it from db
          if self.username.blank?
            self.destroy
            return false
          end

          self.private = true

          # If account private - try to get info from public page via http
          resp = self.update_via_http!
          return false unless resp

          return !self.destroyed?
        elsif e.message =~ /this user does not exist/
          self.destroy
        end
        return false
      end

      self.set_data data
      self.grabbed_at = Time.now
      self.private = false if self.private?
      self.save!
    end

    if exists_username
      exists_username.update_info!
      exists_username.destroy if exists_username.private?
    end

    true
  end

  # Update user via http request to instagram public version
  #
  # @return [Boolean] if update was success
  #
  def update_via_http!
    retries = 0
    begin
      resp = Faraday.new(url: 'http://instagram.com') do |f|
        f.use FaradayMiddleware::FollowRedirects
        f.adapter :net_http
      end.get("/#{self.username}/") do |req|
        req.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36"
      end
    rescue Faraday::ConnectionFailed, Faraday::SSLError, Errno::EPIPE, Errno::ETIMEDOUT => e
      retries += 1
      sleep 10*retries
      retry if retries <= 5
      raise e
    end

    # accounts is private and username is changed
    # so we don't have any way to get new username for user
    # that's why we delete it from database
    if resp.status == 404
      self.destroy
      return false
    end

    html = Nokogiri::HTML(resp.body)
    # content = html.search('script').select{|script| script.attr('src').blank? }.last.text.sub('window._sharedData = ', '').sub(/;$/, '')
    shared_data_element = html.xpath('//script[contains(text(), "_sharedData")]').first
    return false unless shared_data_element
    content = shared_data_element.text.sub('window._sharedData = ', '').sub(/;$/, '')
    json = JSON.parse content
    if json['entry_data'].blank? || json['entry_data']['ProfilePage'].blank?
      self.destroy
      return false
    end
    data = json['entry_data']['ProfilePage'].first['user']

    self.private = data['is_private']

    data['profile_picture'] = data['profile_pic_url']
    data['bio'] = data['biography'] || ''
    data['website'] = data['external_url'] || ''
    data['counts'] = {
      'media' => data['media']['count'],
      'followed_by' => data['followed_by']['count'],
      'follows' => data['follows']['count']
    }

    self.set_data data
    self.grabbed_at = Time.now
    self.save!
  end

  # What the avg interval between followers
  #
  # @return [Float] how often new user following current user, in seconds what avg time between followers
  #
  def follow_speed
    dates = self.user_followers.where("followed_at is not null").order(followed_at: :asc).pluck(:followed_at)
    ((dates.last - dates.first) / dates.size.to_f).round(2)
  end

  def followers_size
    Follower.where(user_id: self.id).size
  end

  def followers_size_cached
    self.data['followers_size'] ||= {'value' => nil, 'updated_at' => nil}
    if self.data['followers_size'].blank? || !self.data['followers_size']['updated_at'] ||
      self.data['followers_size']['updated_at'] < 2.weeks.ago

      self.data['followers_size']['value'] = self.followers_size
      self.save
    end

    self.data['followers_size']['value']
  end

  def followees_size
    Follower.where(follower_id: self.id).size
  end

  # Updating list of all followers for current user
  #
  # @example
  #   User.get('anton_zaytsev').update_followers ignore_exists: true
  #
  # @option options :reload [Boolean] default: false, if reload is set to true,
  #     code will download whole list of followers and replace exists list by new one
  # @option options :ignore_exists [Boolean] default: false, iterates over all followers list
  # @option options :start_cursor [Integer] start time for followers lookup in seconds (timestamp)
  # @option options :finish_cursor [Integer] end time for followers lookup in seconds (timestamp
  # @option options :count [Integer] amount of users requesting from Instagram per request
  #
  # @note
  #   Script stops if found more than 5 exists followers from list in database
  #
  def update_followers *args
    options = args.extract_options!
    UserFollowersCollect.perform user: self, options: options
  end

  def delete_duplicated_followers!
    followers_ids = Follower.where(user_id: self.id).pluck(:follower_id)
    return true if followers_ids.size == followers_ids.uniq.size
    dups = followers_ids.inject({}){ |obj, el| obj[el] ||= 0; obj[el] += 1; obj }.select{ |k, v| v > 1 }
    dups.each do |k, v|
      Follower.where(user_id: self.id, follower_id: k).limit(v-1).destroy_all
    end
  end

  def delete_duplicated_followees!
    followees_ids = Follower.where(follower_id: self.id).pluck(:user_id)
    return true if followees_ids.size == followees_ids.uniq.size
    dups = followees_ids.inject({}){ |obj, el| obj[el] ||= 0; obj[el] += 1; obj }.select{ |k, v| v > 1 }
    dups.each do |k, v|
      Follower.where(follower_id: self.id, user_id: k).limit(v-1).destroy_all
    end
  end

  # Update list of all profiles user follow
  #
  # @example
  #   User.get('anton_zaytsev').update_followees ignore_exists: true
  #
  # @option options :reload [Boolean] default: false, if reload is set to true,
  #     code will download whole list of followers and replace exists list by new one
  # @option options :deep [Boolean] default: false, if need to updated info for each added user in background
  # @option options :ignore_exists [Boolean] default: false, iterates over all followees list
  # @option options :start_cursor [Integer] start time for followers lookup in seconds (timestamp)
  # @option options :finish_cursor [Integer] end time for followers lookup in seconds (timestamp
  # @option options :count [Integer] amount of users requesting from Instagram per request
  #
  # @note
  #   Script stops if found more than 5 exists followers from list in database
  #
  def update_followees *args
    options = args.extract_options!
    UserFolloweesCollect.perform user: self, options: options
  end

  def set_data data
    self.full_name = data['full_name'] unless data['full_name'].nil?
    self.username = data['username']
    self.bio = data['bio'] unless data['bio'].nil?
    self.website = data['website'] unless data['website'].nil?
    self.insta_id = data['id'] if self.insta_id.blank?
    self.profile_picture = data['profile_picture']

    if data['counts'].present?
      self.media_amount = data['counts']['media'] if data['counts']['media'].present?
      self.followed_by = data['counts']['followed_by'] if data['counts']['followed_by'].present?
      self.follows = data['counts']['follows'] if data['counts']['follows'].present?
    end
  end

  def self.get_by_username username
    return false if username.blank? || username.size > 30 || username !~ /\A[a-zA-Z0-9\._]+\z/

    username.downcase!

    user = User.where(username: username).first_or_initialize

    return user if !user.new_record? && user.grabbed_at.present? && user.grabbed_at > 1.month.ago

    ic = InstaClient.new
    resp = ic.client.user_search username

    data = nil
    data = resp.data.select{|el| el['username'].downcase == username.to_s }.first if resp.data.size > 0

    # In case if user changed username, instagram returns record with new data by old username
    if data.nil? && resp.data.size == 1
      d = resp.data.first
      u = User.where(username: d['username'].downcase).first
      if u
        u.update_info!
        if u.username == d['username'].downcase
          user.destroy unless user.new_record?
          return u
        end
      end
      data = d
    end

    if data
      exists = User.where(insta_id: data['id']).first
      if exists
        exists.set_data data
        exists.username = data['username'].downcase
        exists.save
        return exists
      end

      user.set_data data
      user.save
      user
    else
      false
    end
  end

  def self.get username
    return false if username.blank? || username.size > 30

    if (username.class.name == 'Fixnum' || username.numeric?) && username.to_i > 0
      User.where(insta_id: username.to_s).first_or_create
    else
      username = username.to_s.strip.downcase
      User.get_by_username(username)
    end
  end

  # args:
  # total_limit (integer) limit after updater will stop anyway
  # created_from (datetime) time until we diving to update media
  def recent_media *args
    options = args.extract_options!

    max_id = nil

    total_added = 0
    options[:total_limit] ||= 2_000
    tags_found = []

    self.update_info! force: true unless self.insta_id
    raise Exception unless self.insta_id || self.destroyed?
    return false if self.private?

    while true
      time_start = Time.now
      begin
        ic = InstaClient.new
        media_list = ic.client.user_recent_media self.insta_id, count: 100, max_id: max_id
      rescue Instagram::BadRequest => e
        # looks likes account became private
        if e.message =~ /you cannot view this resource/
          self.update_info! force: true
          if !self.private?
            self.recent_media_via_http
          end
          break
        elsif e.message =~ /this user does not exist/
          self.destroy
          return false
        end
        raise e
      end

      ig_time_end = Time.now

      added = 0
      avg_created_time = 0

      data = media_list.data

      media_found = Media.where(insta_id: data.map{|el| el['id']})
      tags_found.concat(Tag.where(name: data.map{|el| el['tags']}.flatten.uniq).to_a).uniq!

      data.each do |media_item|
        # logger.debug "#{">>".green} Start process #{media_item['id']}"
        # ts = Time.now

        media = media_found.select{|el| el.insta_id == media_item['id']}.first
        unless media
          media = Media.new(insta_id: media_item['id'], user_id: self.id)
          added += 1
        end

        media.set_data media_item
        media.tag_names = media_item['tags']

        begin
          media.save if media.changed?
        rescue ActiveRecord::RecordNotUnique => e
          media = Media.find_by_insta_id(media.insta_id)
        end

        media.set_tags media_item['tags'], tags_found
        tags_found.concat(media.tags.to_a).uniq!

        avg_created_time += media['created_time'].to_i

        # logger.debug "#{">>".green} End process #{media_item['id']}. T:#{(Time.now - ts).to_f.round(2)}s"
      end

      break if media_list.data.size == 0

      total_added += added

      time_end = Time.now
      logger.debug "#{">>".green} [#{self.username.green}] / #{media_list.data.size}/#{added.to_s.blue}/#{total_added.to_s.cyan} / IG: #{(ig_time_end-time_start).to_f.round(2)}s / T: #{(time_end - time_start).to_f.round(2)}s"

      avg_created_time = avg_created_time / media_list.data.size

      move_next = false

      break unless media_list.pagination.next_max_id

      if options[:created_from].present?
        if Time.at(avg_created_time) > options[:created_from]
          move_next = true
        end
      elsif options[:ignore_exists]
        move_next = true
      elsif added.to_f / media_list.data.size > 0.1
        move_next = true
      end

      move_next = false if total_added >= options[:total_limit]

      break unless move_next

      max_id = media_list.pagination.next_max_id
    end

    true
  end

  def recent_media_via_http
    retries = 0
    begin
      resp = Faraday.new(url: 'http://instagram.com') do |f|
        f.use FaradayMiddleware::FollowRedirects
        f.adapter :net_http
      end.get("/#{self.username}/") do |req|
        req.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36"
      end
    rescue Faraday::ConnectionFailed, Faraday::SSLError, Errno::EPIPE, Errno::ETIMEDOUT => e
      retries += 1
      sleep 10*retries
      retry if retries <= 5
      raise e
    end

    return false if resp.status == 404

    html = Nokogiri::HTML(resp.body)
    shared_data_element = html.xpath('//script[contains(text(), "_sharedData")]').first
    return false unless shared_data_element
    content = shared_data_element.text.sub('window._sharedData = ', '').sub(/;$/, '')
    json = JSON.parse content

    media = json['entry_data']['ProfilePage'].first['user']['media']['nodes']

    media_exists = Media.where(insta_id: media.map{|r| r['id']})
    media.each do |node|
      item = nil
      item = media_exists.select{|me| me.insta_id == node['id']}.first if media_exists.size > 0
      item = Media.new unless item
      item.user_id = self.id
      item.likes_amount = node['likes']['count']
      item.comments_amount = node['comments']['count']
      item.image = node['display_src']
      item.link = "https://instagram.com/p/#{node['code']}"
      item.save
    end
  end

  def media_frequency last=nil
    media = self.media.order(created_time: :desc)
    if last
      media = media.limit(last)
    end
    media_freq = 0
    if media.size > 0
      media_freq = media.size.to_f / (Time.now.to_i - media.last.created_time.to_i) * 60 * 60 * 24
    end
    media_freq
  end

  def self.fix_exists_username username, exists_insta_id
    user = self.where(username: username).where("insta_id != ?", exists_insta_id).first
    if user.present?
      if user.private?
        user.destroy
      else
        user.update_info! force: true
      end
    end
  end

  # urls (array)
  def self.find_by_urls urls
    found_users = []
    urls.in_groups_of(1000, false).each { |group| found_users.concat User.where(website: group) }
    found_urls = found_users.map{|user| user.website }

    left_urls = urls - found_urls

    users2 = []
    left_urls[0..1000].each do |url|
      user = User.where(website: /#{url}/).first
      users2 << user if user
    end

  end

  def update_location! *args
    options = args.extract_options!

    location_correct = false
    if self.location_updated_at && self.location_updated_at > 1.month.ago && self.location_country && !options[:force]
      location_correct = true
    end
    if location_correct && self.location_country == 'US' && self.location_state.present? && self.location_state.size == 2
      location_correct = false
      self.fix_media_us_states
    end

    if location_correct
      return self.location
    end

    self.update_info!

    return false if self.destroyed?

    media_amount = 50
    media_size = self.media.size

    # do not waste time on private
    if self.private? && media_size == 0
      return self.location
    end

    # get some media, at least latest 50 posts
    if !self.private? && self.media_amount.present? && media_size < media_amount
      self.recent_media ignore_exists: true, total_limit: media_amount
    end

    self.update_media_location

    if self.media.with_coordinates == 0 && self.media_amount > self.media.size
      self.recent_media ignore_exists: true, total_limit: media_amount + 100
      self.update_media_location
    end

    countries = {}
    states = {}
    cities = {}
    self.media.with_coordinates.with_country.each do |media|
      if media.location_country.present?
        countries[media.location_country] ||= 0
        countries[media.location_country] += 1

        if media.location_state.present?
          states[[media.location_country, media.location_state]] ||= 0
          states[[media.location_country, media.location_state]] += 1

          if media.location_city.present?
            cities[[media.location_country, media.location_state, media.location_city]] ||= 0
            cities[[media.location_country, media.location_state, media.location_city]] += 1
          end
        end
      end
    end

    country = countries.to_a.sort{|a,b| a[1]<=>b[1]}.last
    state = states.to_a.sort{|a,b| a[1]<=>b[1]}.last
    city = cities.to_a.sort{|a,b| a[1]<=>b[1]}.last

    return false if self.destroyed?

    self.location_country = (city && city[0] && city[0][0]) || (country && country[0])
    self.location_state = (city && city[0] && city[0][1]) || (state && state[0].last)
    self.location_city = city && city[0] && city[0][2]

    unless self.location?
      self.set_location_from_bio
    end

    self.location_updated_at = Time.now
    self.save

    self.location
  end

  def set_location_from_bio
    return if location?

    self.update_info! if self.bio.nil? || (self.bio.blank? && self.outdated?)

    return false if self.bio.blank?

    country = nil
    state = nil
    city = nil

    match_str = -> (str, substr) {
      str.match(/\A(#{substr})[^a-z]/i) || str.match(/[^a-z](#{substr})[^a-z]/i) || str.match(/[^a-z](#{substr})\Z/i)
    }

    Country.all.each do |c|
      options = [c.name]
      options << 'Russia' if c.alpha2 == 'RU'
      options << 'USA' if c.alpha2 == 'US'
      options = options.join('|')
      match = match_str.call(self.bio, options)
      if match && match[1]
        country = c.alpha2
        break
      end
    end

    predefined = {
      'US' => {
        states: true,
        cities: [
          ['Montgomery', 'AL'], ['Juneau', 'AK'], ['Anchorage', 'AK'], ['Little Rock', 'AR'], ['Phoenix', 'AZ'],
          ['Sacramento', 'CA'], ['San Francisco', 'CA'], ['Bay Area', 'CA'], ['Los Angeles', 'CA'], ['Hollywood', 'CA'],
          ['Santa Monica', 'CA'], ['Malibu', 'CA'], ['Socal', 'CA'], ['San Diego', 'CA'], ['Burbank', 'CA'],
          ['Denver', 'CO'], ['Hartford', 'CT'], ['Bridgeport', 'CT'], ['Dover', 'DE'], ['Wilmington', 'DE'],
          ['Tallahassee', 'FL'], ['Jacksonville', 'FL'], ['Miami', 'FL'], ['Atlanta', 'GA'], ['Hawaii', 'HI'], ['Boise', 'ID'],
          ['Springfield', 'IL'], ['Chicago', 'IL'], ['Indiana', 'IN'], ['Des Moines', 'IA'], ['Topeka', 'KS'], ['Wichita', 'KS'],
          ['Frankfort', 'KY'], ['Louisville', 'KY'], ['Baton Rouge', 'LA'], ['New Orleans', 'LA'],
          ['Augusta', 'ME'], ['Portland', 'ME'], ['Annapolis', 'MD'], ['Baltimore', 'MD'], ['Boston', 'MA'],
          ['Lansing', 'MI'], ['Detroit', 'MI'], ['Saint Paul', 'MN'], ['Minneapolis', 'MN'], ['Jackson', 'MS'],
          ['Billings', 'MT'], ['Omaha', 'NE'],  ['Carson City', 'NV'], ['Las Vegas', 'NV'], ['Concord', 'NH'],
          ['Trenton', 'NJ'], ['Newark', 'NJ'], ['Santa Fe', 'NM'], ['Albuquerque', 'NM'], ['Raleigh', 'NC'],
          ['Bismarck', 'ND'], ['Fargo', 'ND'], ['Brooklyn', 'New York', 'NY'], ['New York', 'NY'],['NYC', 'New York', 'NY'],
          ['Columbus', 'OH'], ['Cleveland', 'OH'], ['Cincinnati', 'OH'], ['Oklahoma', 'OK'], ['Portland', 'OR'],
          ['Harrisburg', 'PA'], ['Pierre', 'SD'], ['Sioux Falls', 'SD'], ['Nashville', 'TN'], ['Memphis', 'TN'],
          ['Dallas', 'TX'], ['Houston', 'TX'], ['Austin', 'TX'], ['San Antonio', 'TX'],
          ['S\.L\.C\.', 'Salt Lake City', 'UT'], ['SLC', 'Salt Lake City', 'UT'], ['Salt Lake City', 'UT'],
          ['Montpelier', 'VT'], ['Burlington', 'VT'], ['Richmond', 'VA'], ['Virginia Beach', 'VA'],
          ['Seattle', 'WA'], ['Charleston', 'WV'], ['Milwaukee', 'WI'], ['Cheyenne', 'WY'],
        ]
      },
      'CA' => {
        states: true,
        cities: [
          ['Montreal', 'QC'], ['Toronto', 'ON'], ['Ottawa', 'ON'], ['Halifax', 'NS'], ['Fredericton', 'NB'], ['Vancouver', 'BC'],
          ['Calgary', 'AB']
        ]
      },
      'AU' => {
        states: true,
        cities: [
          ['Sydney', 'NSW'], ['Melbourne', 'VIC'], ['Adelaide', 'SA'], ['Darwin', 'NT'], ['Brisbane', 'QLD'], ['Hobart', 'TAS'],
          ['Perth', 'WA'], ['Gold Coast', 'QLD'], ['Canberra', 'ACT']
        ]
      },
      'DE' => {
        cities: [
          ['Frankfurt', 'HE']
        ]
      },
      'CN' => {
        cities: [
          ['Shanghai', '31']
        ]
      },
      'JP' => {
        cities: [
          ['Tokyo', '13'],
        ]
      },
      'RU' => {
        cities: [
          ['Moscow', 'MOS']
        ]
      },
      'GB' => {
        cities: [
          ['London', 'LND'], ['Manchester', 'MAN']
        ]
      }
    }

    (country ? predefined.select{|cc, d| cc == country} : predefined).each do |country_code, data|
      states = Country[country_code].states

      if data[:cities]
        data[:cities].each do |row|
          match = match_str.call(self.bio, row[0])
          if match && match[1]
            city = row.size == 2 ? row[0] : row[1]
            state = states[row.last]['name']
            country = country_code unless country
            break
          end
        end
      end

      if data[:states] && states && states.size > 0 && !city && !state
        states_ar = states.inject([]){|ar, (k,v)| ar << [v['name'], k]; ar}
        states_ar.each do |row|
          match = match_str.call(self.bio, row[0])
          if match && match[1]
            begin
              state = states[row.last]['name']
              country = country_code
            rescue => e
              binding.pry
            end
            break
          end
        end
      end

      break if city && state && country
    end

    self.location_country = country if country
    self.location_state = state if state
    self.location_city = city if city
  end

  def get_location_from_bio!
    self.set_location_from_bio

    if self.changed?
      self.location_updated_at = Time.now if self.location_country && self.location_state
      self.save
    end
  end

  def update_media_location
    if self.username.blank? && self.insta_id.present?
      self.update_info! force: true
    end

    return false if self.destroyed?

    logger.debug ">> update_media_location: #{self.username.green}"
    with_location = self.media.with_coordinates
    with_location_amount = with_location.size
    processed = 0

    with_location.where(location_country: nil).each_with_index do |media, index|
      processed += 1
      # if user obviously have lots of media in one place, leave other media, check each 10th media
      if index % 10 == 0
        data = Media.where(user_id: self.id).where("location_lat IS NOT NULL").inject({}){|obj, m| obj[m.location_country] ||= []; obj[m.location_country] << m; obj}
        amounts = []
        data.each{ |k, v| amounts << [k, v.size] }
        amounts = amounts.sort{ |a, b| a[1] <=> b[1] }.reverse

        if !amounts[0][0].nil? && with_location_amount > 20
          logger.debug ">> update_media_location: #{self.username.green}. stopped because most of the media has same country"
          break
        end
      end

      media.update_location!

      logger.debug ">> update_media_location: #{self.username.green}. progress: #{(processed / with_location_amount.to_f * 100).to_i}%"
    end
  end

  def update_avg_data! *args
    options = args.extract_options!

    return true if self.avg_likes_updated_at && self.avg_likes_updated_at > 1.month.ago && !options[:force]

    likes_amount = 0
    comments_amount = 0
    media_amount = 0

    options[:total_limit] ||= 50
    media_limit = [options[:total_limit], 100].max

    self.update_info! force: true

    media = self.media.order(created_time: :desc).where("created_time < ?", 1.day.ago).limit(media_limit)

    if media.size < options[:total_limit]
      Rails.logger.info "[#{"Update AVG Data".green}] [#{self.username.cyan}] Grabbing more media, current: #{media.size}"
      self.recent_media ignore_exists: true, total_limit: options[:total_limit]
      media = self.media.order(created_time: :desc).where("created_time < ?", 1.day.ago).limit(media_limit)
      Rails.logger.info "[#{"Update AVG Data".green}] [#{self.username.cyan}] Grabbed more media, current: #{media.size}"
    end

    return false if self.destroyed?

    less_day_media = false
    if media.size == 0
      media = self.media.order(created_time: :desc).limit(media_limit)
      less_day_media = true
    end

    return false if media.size == 0

    media.each do |media_item|
      # if diff between when media added to database and date when it was pasted less than 2 days ago
      # OR likes/comments amount is blank
      if !less_day_media && (media_item.updated_at - media_item.created_time < 2.days || media_item.likes_amount.blank? || media_item.comments_amount.blank?)
        Rails.logger.info "[#{"Update AVG Data".green}] [#{self.username.cyan}] Updating media #{media_item.id}"
        media_item.update_info!
      end

      # if media doesn't exists anymore in instagram
      next if media_item.destroyed? || media_item.likes_amount.blank? || media_item.comments_amount.blank?

      likes_amount += media_item.likes_amount
      comments_amount += media_item.comments_amount
      media_amount += 1
    end

    return false if media_amount == 0

    avg_likes = likes_amount / media_amount
    avg_comments = comments_amount / media_amount

    self.avg_likes = avg_likes
    self.avg_likes_updated_at = Time.now
    self.avg_comments = avg_comments
    self.save
  end

  def outdated?
    self.grabbed_at.blank? || self.grabbed_at < 1.week.ago || self.bio.nil? || self.website.nil? || self.follows.blank? ||
      self.followed_by.blank? || self.full_name.nil? || self.insta_id.blank? || self.username.blank?
  end

  def actual?
    !self.outdated?
  end

  def self.by_engagement
    users_ids = User.connection.execute("
      SELECT a.id from (
        SELECT id, avg_likes/followed_by as eng, location_country
        FROM users
        WHERE followed_by > 1000 && avg_likes is not null order by eng desc
      ) as a
      WHERE a.eng > 0.015 && a.location_country in ('us', 'united states')
    ").to_a.map{|e| e[0]}
  end

  def engagement
    return false unless self.avg_likes > 0 || self.followed_by > 0
    (self.avg_likes/self.followed_by.to_f).round(2)
  end

  # def get_feedly
  #   return false if self.website.blank?
  #   f = Feedly.where('feedly_url = :w OR website = :w', w: self.website).first
  #   unless f
  #     f = Feedly.process self.website
  #   end
  #   f
  # end

  def self.from_usernames usernames
    users = User.where(username: usernames).to_a

    not_processed = []
    not_found = usernames - users.map{|u| u.username}
    if not_found.size > 0
      not_found.each do |username|
        user = User.get username
        if user
          users << user
        else
          not_processed << username
        end
      end
    end

    users
  end

  def self.from_usernames_ids usernames
    users = User.where(username: usernames).pluck(:id, :username)

    not_processed = []
    not_found = usernames - users.map{|u| u[1]}
    if not_found.size > 0
      not_found.each do |username|
        user = User.get username
        if user
          users << [user.id, user.username]
        else
          not_processed << username
        end
      end
    end

    users
  end

  def update_feedly!
    return false if self.website.blank?

    record = Feedly.where(user_id: self.id).first_or_initialize

    if record.new_record?
      rec = Feedly.where(website: self.website).where(user_id: nil).first
      if rec
        record = rec
        record.user_id = self.id
      end
    end

    if !record.new_record? && record.website.present? && record.website == self.website && record.grabbed_at.present? && record.grabbed_at > 1.month.ago
      record.save if record.changed?
      return record
    end

    client = Feedlr::Client.new

    retries = 0
    begin
      resp = client.search_feeds self.website
    rescue Feedlr::Error, Feedlr::Error::RequestTimeout => e
      retries += 1
      sleep 10*retries
      retry if retries <= 5
      raise e
    end

    if resp['results'] && resp['results'].size > 0
      result = resp['results'].first

      record.feedly_url = result['website']
      record.feed_id = result['feedId']
      record.subscribers_amount = result['subscribers'] || 0
    end

    record.website = self.website
    record.grabbed_at = Time.now
    record.save!

    true
  end

  def must_save
    begin
      self.save!
    rescue ActiveRecord::RecordNotUnique => e
      if e.message =~ /index_users_on_insta_id/
        return User.where(username: self.username).first
      elsif e.message =~ /index_users_on_username/
        exists_user = User.where(username: self.username).first

        if exists_user.insta_id == self.insta_id
          return exists_user
        else
          exists_user.update_info! force: true
          if exists_user.private? || exists_user.username == self.username
            exists_user.destroy
            begin
              self.save!
            rescue ActiveRecord::RecordNotUnique => e
              if e.message =~ /index_users_on_insta_id/
                self.destroy
                return User.where(insta_id: self.insta_id).first
              end
            end
          end
        end
      else
        raise Exception.new "Invalid user #{self.insta_id} / #{self.username}"
      end
    end

    unless self.valid?
      if self.errors[:insta_id]
        return User.where(username: self.username).first
      elsif self.errors[:username]
        exists_user = User.where(username: self.username).first

        if exists_user.insta_id == self.insta_id
          return exists_user
        else
          exists_user.update_info! force: true
          if exists_user.private? || exists_user.username == self.username
            exists_user.destroy
            self.save!
          end
        end
      else
        raise Exception.new "Invalid user #{self.insta_id} / #{self.username}"
      end
    end

    self
  end

  def location?
    self.location_country.present?
  end

  def location
    return false unless self.location?
    [self.location_country, self.location_state, self.location_city].join(', ')
  end

  def get_followers_analytics recount: false
    fa = data_get_value 'followers_analytics', lifetime: 2.weeks, recount: recount

    if !fa
      if self.followers_info_updated_at.blank? || self.followers_info_updated_at < 1.week.ago
        if self.followers_size < self.followed_by * 0.95
          UserFollowersUpdateWorker.perform_async self.id
        else
          UserFollowersAnalyticsWorker.perform_async self.id
        end
        return false
      end

      amounts = {}

      groups = ['0-100', '100-250', '250-500', '500-1000', '1,000-10,000', '10,000+']

      followers_ids = Follower.where(user_id: self.id).pluck(:follower_id)
      followers_ids.in_groups_of(100_000, false) do |ids|
        User.where(id: ids).where('followed_by is not null').pluck(:followed_by).each do |followers_size|
          groups.each do |group|
            amounts[group] ||= 0
            from, to = group.gsub(/,|\+/, '').split('-').map(&:to_i)
            if to.present?
              if followers_size >= from && followers_size < to
                amounts[group] += 1
              end
            else
              if followers_size >= from
                amounts[group] += 1
              end
            end
          end
        end
      end

      UserFollowersUpdateWorker.perform_async self.id

      fa = amounts
      data_set_value 'followers_analytics', amounts
      self.save
    end

    fa
  end

  def get_popular_followers_percentage recount: false
    pfp = data_get_value 'popular_followers_percentage', lifetime: 7.days, recount: recount
    if !pfp
      if self.followers_info_updated_at && self.followers_info_updated_at > 1.week.ago && self.followers_size > self.followed_by * 0.95
        fol_ids = self.follower_ids
        amount = 0
        fol_ids.in_groups_of(100_000, false) do |g|
          amount += User.where(id: g).where('followed_by > 250').size
        end
        pfp = (amount / fol_ids.size.to_f * 100).round
        data_set_value 'popular_followers_percentage', pfp
        self.save
      else
        return false
      end
    end

    pfp
  end

  def followers_info_updated_at
    DateTime.parse(self.data['followers_info_updated_at']) if self.data['followers_info_updated_at'].present?
  end

  def followers_info_updated_at=followers_info_updated_at
    self.data['followers_info_updated_at'] = followers_info_updated_at
  end

  def followees_info_updated_at
    DateTime.parse(self.data['followees_info_updated_at']) if self.data['followees_info_updated_at'].present?
  end

  def followees_info_updated_at=followees_info_updated_at
    self.data['followees_info_updated_at'] = followees_info_updated_at
  end

  def followers_updated_time!
    if self.followed_by/self.followers_size.to_f >= 0.95
      self.update_attribute :followers_updated_at, Time.now
    end
  end

  def followees_updated_time!
    if self.follows/self.followees_size.to_f >= 0.95
      self.update_attribute :followees_updated_at, Time.now
    end
  end

  def follower_ids
    Follower.where(user_id: self.id).pluck(:follower_id)
  end

  def followers_preparedness recount: false
    fp = data_get_value 'followers_preparedness', lifetime: 1.day, recount: recount
    if !fp
      parts = 2
      count = 0
      count += self.followers_updated_at.present? ? 1 : 0
      count += self.followers_info_updated_at > 1.week.ago ? 1 : 0

      fp = (count/parts.to_f*100).round
      data_set_value 'followers_preparedness', fp
      self.save
    end
    fp
  end

  def data_get_value key, lifetime: 7.days, recount: false
    item = self.data[key]
    if !item || item.size == 0 || !item['value'] || item['updated_at'].blank? || item['updated_at'] < lifetime.ago || recount
      return false
    end
    item['value']
  end

  def data_set_value key, value
    self.data[key] ||= {}
    self.data[key]['value'] = value
    self.data[key]['updated_at'] = Time.now.utc
  end

  def fix_media_us_states
    states = Country['US'].states
    self.media.where(location_country: 'US').where('length(location_state) = 2').each do |media|
      state = states[media.location_state]
      media.update_column :location_state, state['name'] if state
    end
  end

  def followers_increase
    followers_per_month = self.followers_chart_data
    income_per_month = []
    followers_per_month.each_with_index do |row, index|
      row[1] -= followers_per_month[index-1][1] if index > 0
      income_per_month << row
    end
    income_per_month
  end

  def followers_chart_data
    data = Follower.connection.execute("
        SELECT * FROM (
            SELECT sum(1) as total, extract(month from followed_at) as month, extract(year from followed_at) as year
            FROM followers
            WHERE user_id=#{self.id} AND followed_at is not null
            GROUP BY extract(month from followed_at), extract(year from followed_at)
        ) as temp
        ORDER BY year, total
    ")

    data = data.to_a.inject({}) do |obj, el|
      date = DateTime.parse("#{el['year']}/#{el['month']}/1").to_i * 1000
      obj[date] = el['total'].to_i
      obj
    end

    data.sort
  end
end
