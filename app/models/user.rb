class User < ActiveRecord::Base

  has_many :media, class_name: 'Media', dependent: :destroy

  has_many :user_followers, class_name: 'Follower', foreign_key: :user_id, dependent: :destroy
  has_many :followers, through: :user_followers

  has_many :user_followees, class_name: 'Follower', foreign_key: :follower_id, dependent: :destroy
  has_many :followees, through: :user_followees

  scope :not_grabbed, -> { where grabbed_at: nil }
  scope :not_private, -> { where private: [nil, false] }
  scope :privates, -> { where private: true }
  scope :outdated, -> { where('grabbed_at is null OR grabbed_at < ? OR bio is null OR website is null of follows is null OR followed_by is null', 7.days.ago) }

  before_save do
    # Catch email from bio
    if self.bio.present?
      email_regex = /([\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+)/
      m = self.bio.match(email_regex)
      if m && m[1]
        self.email = m[1].downcase.sub(/^[\.\-\_]+/, '')
      end
    end

    if self.username_changed?
      self.username = self.username.strip.gsub(/\s/, '')

      if self.insta_id.present?
        User.fix_exists_username(self.username, self.insta_id)
      end
    end
  end

  def full_name=(value)
    if value.present?
      value = value.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      value = value.encode(value.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      value.strip!
      value = value[0, 255]
    end

    # this is same as self[:attribute_name] = value
    write_attribute(:full_name, value)
  end

  def bio=(value)
    if value.present?
      value = value.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      value = value.encode(value.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      value.strip!
    end

    write_attribute(:bio, value)
  end

  def website=(value)
    if value.present?
      value = value.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      value = value.encode(value.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      value = value[0, 255]
    end

    write_attribute(:website, value)
  end


  def update_info! *args
    options = args.extract_options!

    return true if self.actual? && !options[:force]

    if self.insta_id.blank? && self.username.present?
      retries = 0
      begin
        client = InstaClient.new.client
        resp = client.user_search(self.username)
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::BadRequest, Instagram::InternalServerError, Instagram::GatewayTimeout,
        JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
        logger.info "#{">> issue".red} #{e.class.name} :: #{e.message}"
        sleep 10
        retries += 1
        retry if retries <= 5
        raise e
      end

      data = nil
      data = resp.data.select{|el| el['username'].downcase == self.username.downcase }.first if resp.data.size > 0

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

      if data
        self.insta_data data
      else
        self.destroy
        return false
      end
    end

    exists_username = nil

    return false if self.insta_id.blank?

    retries = 0

    begin
      client = InstaClient.new.client
      info = client.user(self.insta_id)
      data = info.data

      exists_username = nil
      # if we already have in database user with same username
      if data['username'] != self.username
        exists_username = User.where(username: data['username']).first
        if exists_username
          exists_username.username = "#{exists_username.username}#{Time.now.to_i}"
          exists_username.save
        end
      end
    rescue Instagram::BadRequest => e
      if e.message =~ /you cannot view this resource/

        # if user is private and we don't have it's username, than just remove it from db
        if self.private? && self.username.blank?
          self.destroy
          return false
        end

        self.private = true
        self.grabbed_at = Time.now

        # If account private - try to get info from public page via http
        # begin
          self.update_private_account
        # rescue => e
          # binding.pry
        # end

        if self.destroyed?
          return false
        else
          self.save
          return true
        end
      elsif e.message =~ /this user does not exist/
        self.destroy
      end
      return false
    rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::InternalServerError, Instagram::GatewayTimeout,
      JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
      sleep 10
      retries += 1
      retry if retries <= 5
      raise e
    end

    self.username = data['username']
    self.bio = data['bio']
    self.website = data['website']
    self.full_name = data['full_name']
    self.followed_by = data['counts']['followed_by']
    self.follows = data['counts']['follows']
    self.media_amount = data['counts']['media']
    self.grabbed_at = Time.now
    self.save

    if exists_username
      exists_username.update_info!
      exists_username.destroy if exists_username.private?
    end

    true
  end

  def update_private_account
    retries = 0
    begin
      resp = Curl::Easy.perform("http://instagram.com/#{self.username}/") do |curl|
        curl.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36"
        curl.verbose = Rails.env.development?
        curl.follow_location = true
      end
    rescue Curl::Err::HostResolutionError, Curl::Err::SSLConnectError, Curl::Err::GotNothingError => e
      sleep 10
      retries += 1
      retry if retries < 5
      return false
    end

    # accounts is private and username is changed
    # so we don't have any way to get new username for user
    # that's why we delete it from database
    if resp.response_code == 404
      self.destroy
      return false
    end

    html = Nokogiri::HTML(resp.body)
    # content = html.search('script').select{|script| script.attr('src').blank? }.last.text.sub('window._sharedData = ', '').sub(/;$/, '')
    content = html.xpath('//script[contains(text(), "_sharedData")]').first.text.sub('window._sharedData = ', '').sub(/;$/, '')
    json = JSON.parse content
    user = json['entry_data']['UserProfile'].first['user']

    # self.full_name = resp.body.match(/"full_name":"([^"]+)"/)[1] if self.full_name.blank?
    self.full_name = user['full_name']
    self.bio = user['bio']
    self.website = user['website']
    # self.media_amount = resp.body.match(/"media":(\d+)/)[1] if self.media_amount.blank?
    self.media_amount = user['counts']['media']
    # self.followed_by = resp.body.match(/"followed_by":(\d+)/)[1] if self.followed_by.blank?
    self.followed_by = user['counts']['followed_by']
    # self.follows = resp.body.match(/"follows":(\d+)/)[1] if self.follows.blank?
    self.follows = user['counts']['follows']

    self.save
  end


  # Script stops if found more than 5 exists followers from list in database
  # Params
  # reload (boolean) - default: false, if reload is set to true, code will download whole list of followers and replace exists list by new one
  # deep (boolean) - default: false, if need to updated info for each added user straight in code
  # ignore_exists (boolean) - default: false, iterates over all followers list
  def update_followers *args
    return false if self.insta_id.blank?

    options = args.extract_options!

    next_cursor = nil

    self.update_info!

    return false if self.destroyed? || self.private?

    followed = self.followed_by
    logger.debug ">> [#{self.username.green}] followed by: #{followed}"

    if options[:reload]
      self.follower_ids = []
    end

    total_exists = 0
    total_added = 0

    while true
      start = Time.now

      exists = 0
      added = 0
      retries = 0

      begin
        client = InstaClient.new.client
        resp = client.user_followed_by self.insta_id, cursor: next_cursor, count: 100
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::InternalServerError, Instagram::GatewayTimeout,
        JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
        sleep 10
        retries += 1
        retry if retries <= 5
      rescue Instagram::BadRequest => e
        if e.message =~ /you cannot view this resource/
          break
        end
        raise e
      end

      end_ig = Time.now

      users = User.where(insta_id: resp.data.map{|el| el['id']})
      fols = Follower.where(user_id: self.id, follower_id: users.map{|el| el.id})

      follower_ids_list = self.follower_ids.to_a

      resp.data.each do |user_data|
        logger.debug "Row #{user_data['username']} start"

        new_record = false

        user = users.select{|el| el.insta_id == user_data['id'].to_i}.first
        unless user
          user = User.new insta_id: user_data['id']
          new_record = true
        end

        if user.insta_id.present? && user_data['id'].present? && user.insta_id != user_data['id'].to_i
          raise Exception
        end
        user.insta_data user_data

        if options[:deep] && !user.private && (user.updated_at.blank? || user.updated_at < 1.month.ago || user.website.nil? || user.follows.blank? || user.followed_by.blank? || user.media_amount.blank?)
          user.update_info!
        end

        begin
          user.save if user.changed?
        rescue ActiveRecord::RecordNotUnique => e
          if e.message.match('Duplicate entry') && e.message =~ /index_users_on_insta_id/
            user = User.where(insta_id: user_data['id']).first
            new_record = false
          elsif e.message.match('Duplicate entry') && e.message =~ /index_users_on_username/
            exists_user = User.where(username: user_data['username']).first
            if exists_user.insta_id != user_data['id']
              exists_user.destroy
              retry
            end
          else
            raise e
          end
        end

        if new_record
          Follower.create(user_id: self.id, follower_id: user.id)
          added += 1
        else
          fol = Follower.where(user_id: self.id, follower_id: user.id)

          if options[:reload]
            fol.first_or_create
            added += 1
          else
            fol_exists = fols.select{|el| el.follower_id == user.id }.first

            if fol_exists
              exists += 1
            else
              fol = fol.first_or_initialize
              if fol.new_record?
                fol.save
                added += 1
              else
                exists += 1
              end
            end
          end
        end

        unless follower_ids_list.include?(user.id)
          follower_ids_list << user.id
        end

        user = nil # trying to save some RAM but nulling variable
        logger.debug "Row #{user_data['username']} end"
      end

      total_exists += exists
      total_added += added

      finish = Time.now
      logger.debug ">> [#{self.username.green}] followers:#{follower_ids_list.size}/#{followed} request:#{(finish-start).to_f.round(2)}s :: IG request: #{(end_ig-start).to_f.round(2)} / exists: #{exists} (#{total_exists.to_s.light_black}) / added: #{added} (#{total_added.to_s.light_black})"

      break if !options[:ignore_exists] && exists >= 5

      next_cursor = resp.pagination['next_cursor']

      break unless next_cursor
    end

    self.save
  end


  def update_followers_async
    ProcessFollowersWorker.spawn self.id
  end


  # Params:
  # reload (boolean) - fully re-check all followers
  # ignore_exists (boolean)
  def update_followees *args
    return false if self.insta_id.blank?

    options = args.extract_options!

    next_cursor = nil

    self.update_info!

    return false if self.destroyed? || self.private?

    logger.debug ">> [#{self.username.green}] follows: #{self.follows}"

    return false if self.follows == 0

    if options[:reload]
      self.followee_ids = []
    end

    # total_exists = 0
    # total_added = 0

    exists = 0

    followee_ids = []
    begining_time = Time.now

    while true
      start = Time.now
      retries = 0
      begin
        client = InstaClient.new.client
        resp = client.user_follows self.insta_id, cursor: next_cursor, count: 100
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::InternalServerError, Instagram::GatewayTimeout,
        JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
        logger.info "#{">> issue".red} #{e.class.name} :: #{e.message}"
        sleep 10
        retries += 1
        retry if retries <= 5
        raise e
      rescue Instagram::BadRequest => e
        if e.message =~ /you cannot view this resource/
          break
        end
        raise e
      end
      next_cursor = resp.pagination['next_cursor']

      data = resp.data

      users = User.where(insta_id: data.map{|el| el['id']})
      fols = Follower.where(follower_id: self.id, user_id: users.map{|el| el.id}) unless options[:reload]

      data.each do |user_data|
        user = users.select{|el| el.insta_id == user_data['id'].to_i}.first
        unless user
          user = User.new(insta_id: user_data['id'])
        end

        user.insta_data user_data

        if options[:deep] && !user.private && (user.updated_at.blank? || user.updated_at < 1.month.ago || user.website.nil? || user.follows.blank? || user.followed_by.blank? || user.media_amount.blank?)
          user.update_info!
        end

        begin
          user.save if user.changed?
        rescue ActiveRecord::RecordNotUnique => e
          if e.message.match('Duplicate entry') && e.message =~ /index_users_on_insta_id/
            user = User.where(insta_id: user_data['id']).first
            new_record = false
          elsif e.message.match('Duplicate entry') && e.message =~ /index_users_on_username/
            exists_user = User.where(username: user_data['username']).first
            if exists_user.insta_id != user_data['id']
              exists_user.destroy
              retry
            end
          else
            raise e
          end
        end

        fol = nil
        fol = fols.select{|el| el.user_id == user.id }.first unless options[:reload]
        fol = Follower.where(follower_id: self.id, user_id: user.id).first_or_initialize unless fol

        if !options[:reload] && !fol.new_record?
          exists += 1
        end

        fol.save if fol.changed?

        followee_ids << user.id
      end

      logger.debug "followees: #{followee_ids.size}/#{follows} / request:#{(Time.now-start).to_f.round(2)}s / exists: #{exists}"

      break if !options[:ignore_exists] && exists >= 5
      break unless next_cursor
    end

    self.save
  end

  def insta_data data
    self.username = data['username']
    self.bio = data['bio'] unless data['bio'].nil?
    self.website = data['website'] unless data['website'].nil?
    self.full_name = data['full_name'] unless data['full_name'].nil?
    self.insta_id = data['id'] if self.insta_id.blank?
  end

  def self.add_by_username username
    return false if username.blank? || username.size > 30 || username !~ /\A[a-zA-Z0-9\._]+\z/

    user = User.where(username: username).first_or_initialize

    return user if !user.new_record? && user.grabbed_at.present? && user.grabbed_at > 1.month.ago

    retries = 0
    begin
      client = InstaClient.new.client
      resp = client.user_search username
    rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::BadRequest, Instagram::InternalServerError, Instagram::GatewayTimeout,
      JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
      sleep 10
      retries += 1
      retry if retries <= 5
    end

    data = nil
    data = resp.data.select{|el| el['username'].downcase == username.to_s.downcase }.first if resp.data.size > 0

    # In case if user changed username, instagram returns record with new data by old username
    if data.nil? && resp.data.size == 1
      d = resp.data.first
      u = User.where(username: d['username']).first
      if u
        u.update_info!
        if u.username == d['username']
          user.destroy unless user.new_record?
          return u
        end
      end
      data = d
    end

    if data
      exists = User.where(insta_id: data['id']).first
      if exists
        exists.username = data['username']
        exists.save
        return exists
      end

      user.insta_data data
      user.save
      user
    else
      false
    end
  end

  def self.get username
    if username.numeric?
      User.where('id = :id or insta_id = :id', id: username).first_or_create(insta_id: username)
    else
      User.add_by_username(username)
    end
  end

  def self.get_emails usernames=[]
    users = User.all
    users = users.where(username: usernames).where('email is null OR email="" OR bio is null OR bio=""').where('grabbed_at < ?', 3.days.ago) if usernames.size > 0
    users.find_each(batch_size: 1000) do |user|
      user.update_info! if user.email.blank? || user.bio.blank?
    end
  end

  def self.report_by_emails emails
    results = {}

    emails.in_groups_of(100, false) do |emails_group|
      User.where(email: emails_group).each do |user|
        results[user.email] = [user.full_name, user.username, user.bio, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
      end
    end

    GeneralMailer.report_by_emails(emails, results).deliver
  end

  def self.get_bio_by_usernames usernames
    results = []

    usernames.in_groups_of(2000, false) do |usernames_group|
      users = User.where(username: usernames_group)

      (usernames_group - users.pluck(:username)).each do |username|
        u = User.add_by_username username
        if u
          u.update_info!
          results << [u.username, u.bio]
        end
      end

      users.each do |user|
        results << [user.username, user.bio]
      end
    end

    GeneralMailer.get_bio_by_usernames(results).deliver
  end

  # args:
  # total_limit (integer) limit after updater will stop anyway
  # created_from (datetime) time until we diving to update media
  def recent_media *args
    options = args.extract_options!

    max_id = nil

    total_added = 0
    options[:total_limit] ||= 2_000

    self.update_info! unless self.insta_id
    raise Exception unless self.insta_id || self.destroyed?
    return false if self.private?

    while true
      time_start = Time.now
      retries = 0
      begin
        client = InstaClient.new.client
        media_list = client.user_recent_media self.insta_id, count: 100, max_id: max_id
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::InternalServerError, Instagram::GatewayTimeout,
        JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
        sleep 10
        retries += 1
        retry if retries <= 5
        raise e
      rescue Instagram::BadRequest => e
        if e.message =~ /you cannot view this resource/
          break
        end
        raise e
      end

      ig_time_end = Time.now

      added = 0
      avg_created_time = 0

      data = media_list.data

      media_found = Media.where(insta_id: data.map{|el| el['id']})
      tags_found = Tag.where(name: data.map{|el| el['tags']}.flatten.uniq).select(:id, :name)

      data.each do |media_item|
        logger.debug "#{">>".green} Start process #{media_item['id']}"

        media = media_found.select{|el| el.insta_id == media_item['id']}.first
        unless media
          media = Media.new(insta_id: media_item['id'], user_id: self.id)
        end

        media.media_data media_item, tags_found

        added += 1 if media.new_record?

        begin
          media.save
        rescue ActiveRecord::RecordNotUnique => e
        end

        avg_created_time += media['created_time'].to_i

        logger.debug "#{">>".green} End process #{media_item['id']}"
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

    self.media
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
    user = self.where(username: username).where('insta_id != ?', exists_insta_id).first
    user.update_info! force: true if user.present?
  end

  # urls (array)
  def self.find_by_urls urls
    found_users = []
    urls.in_groups_of(1000, false).each { |group| found_users.concat User.where(website: group) }
    found_urls = found_users.map{|user| user.website }

    left_urls = urls - found_urls

    users2 = []
    left_urls[0..1000].each do |url|
      user = User.where('website like ?', "%#{url}%").first
      users2 << user if user
    end

    binding.pry

  end

  def popular_location *args
    options = args.extract_options!

    if self.location_updated_at && self.location_updated_at > 1.month.ago && self.location_country && !options[:force]
      self.location
    end

    self.update_info! if !self.private? && (self.media_amount.blank? || !self.grabbed_at.present? || self.grabbed_at < 7.days.ago)

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

    if self.media.with_location == 0 && self.media_amount > self.media.size
      self.recent_media ignore_exists: true, total_limit: media_amount + 100
      self.update_media_location
    end

    countries = {}
    states = {}
    cities = {}
    self.media.with_location.where('location_country is not null && location_country != "" OR location_state is not null && location_state != "" OR location_city is not null && location_city != ""').each do |media|
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

    self.location_country = country && country[0]
    self.location_state = state && state[0].join(', ')
    self.location_city = city && city[0].join(', ')
    self.location_updated_at = Time.now
    self.save

    self.location
  end

  alias :update_location! :popular_location

  def location
    {
      country: self.location_country,
      state: self.location_state,
      city: self.location_city,
    }
  end

  def update_media_location
    logger.debug ">> update_media_location: #{self.username.green}"
    with_location = self.media.with_location
    with_location_amount = with_location.size

    with_location.where('location_country is null').each_with_index do |media, index|
      # if user obviously have lots of media in one place, leave other media
      if index % 5 == 0
        resp = Tag.connection.execute("SELECT count(id), location_country FROM `media`  WHERE `media`.`user_id` = #{self.id} AND (location_lat is not null and location_lat != '') GROUP BY location_country").to_a

        # if we don't have media where location_country is blank
        without_country_amount = resp.select{ |el| el[1].nil? }.first.try(:first)

        break if without_country_amount.blank?

        # if we have at least 10% of same location
        if with_location_amount > 20 && without_country_amount / with_location_amount.to_f < 0.9
          # if resp.size == 2
            break
          # else
            # binding.pry
            # raise
          # end
        end
      end

      media.update_location!

      sleep(5)
    end
  end

  def update_avg_data *args
    options = args.extract_options!
    media = self.media.order(created_time: :desc).where('created_time < ?', 1.day.ago)

    likes_amount = 0
    comments_amount = 0
    media_amount = 0

    options[:total_limit] ||= 50

    if media.size < options[:total_limit]
      self.recent_media total_limit: options[:total_limit]
      media = self.media.order(created_time: :desc).where('created_time < ?', 1.day.ago)
    end

    return false if media.size == 0

    media.each do |media_item|
      # if diff between when media added to database and date when it was pasted less than 2 days ago
      # OR likes/comments amount is blank
      if media_item.updated_at - media_item.created_time < 2.days || media_item.likes_amount.blank? || media_item.comments_amount.blank?
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
    self.avg_comments_updated_at = Time.now
    self.save
  end

  def self.process_usernames usernames
    processed = 0
    initial = usernames.size
    added = []

    usernames.each do |row|
      logger.debug "Start #{row[0]}"
      user = User.add_by_username row[0]
      if user && user.email.blank?
        user.email = row[2]
        user.save
      end

      if user
        user.update_info! if user.grabbed_at.blank? || user.grabbed_at < 1.week.ago
        added << [user.username, user.full_name, user.website, user.bio, user.follows, user.followed_by, user.media_amount, user.email]
      end

      processed += 1

      logger.debug "Progress #{processed}/#{initial} (#{(processed/initial.to_f * 100).to_i}%)"
    end

    csv_string = CSV.generate do |csv|
      csv << ['Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followers', 'Media amount', 'Email']
      added.each do |row|
        csv << row
      end
    end

    logger.debug "Added #{added.size}"

    GeneralMailer.process_usernames_file(csv_string).deliver
  end

  def outdated?
    self.grabbed_at.blank? || self.grabbed_at < 20.days.ago || self.bio.nil? || self.website.nil? || self.follows.blank? ||
      self.followed_by.blank? || self.full_name.nil?
  end

  def actual?
    !self.outdated?
  end

end
