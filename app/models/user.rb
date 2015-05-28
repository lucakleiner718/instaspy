class User

  include Mongoid::Document
  field :insta_id, type: Integer
  field :username, type: String
  field :full_name, type: String
  field :bio, type: String
  field :website, type: String
  field :follows, type: Integer
  field :followed_by, type: Integer
  field :media_amount, type: Integer
  field :private, type: Boolean, default: false
  field :grabbed_at, type: DateTime
  field :email, type: String
  field :location_country, type: String
  field :location_state, type: String
  field :location_city, type: String
  field :location_updated_at, type: DateTime
  field :avg_likes, type: Integer
  field :avg_likes_updated_at, type: DateTime
  field :avg_comments, type: Integer
  field :avg_comments_updated_at, type: DateTime
  include Mongoid::Timestamps # created_at need to know when user added to database and filter only new added users

  index({ insta_id: 1 }, { drop_dups: true, background: true })
  index({ username: 1 }, { drop_dups: true, background: true })
  index comments: 1
  index avg_comments_updated_at: 1
  index avg_likes: 1
  index avg_likes_updated_at: 1
  index created_at: 1
  index email: 1
  index followed_by: 1
  index grabbed_at: 1
  index location_city: 1
  index location_country: 1
  index location_state: 1
  index media_amount: 1
  index updated_at: 1
  index website: 1

  has_many :media, class_name: 'Media', dependent: :destroy
  has_many :feedly

  validates :insta_id, uniqueness: true, if: 'insta_id.present?'
  validates :username, uniqueness: true, if: 'username.present?'

  scope :not_grabbed, -> { where grabbed_at: nil }
  scope :not_private, -> { where private: false }
  scope :privates, -> { where private: true }
  scope :outdated, -> (date=7.days) { scoped.or(grabbed_at: nil).or(:grabbed_at.lt => date.ago).or(bio: nil, website: nil, follows: nil, followed_by: nil, media_amount: nil) }
  scope :with_url, -> { where(:website.ne => nil).and(:website.ne => '') }
  scope :without_likes, -> { scoped.or(avg_likes: nil, avg_likes_updated_at: nil).or(:avg_likes_updated_at.lt => 1.month.ago) }
  scope :without_location, -> { scoped.or(location_updated_at: nil).or(:location_updated_at.lt => 3.months.ago) }
  scope :with_media, -> { where(:media_amount.gt => 0) }

  before_save do
    # Catch email from bio
    if self.bio_changed? && self.bio.present?
      email_regex = /([\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+)/
      m = self.bio.downcase.match(email_regex)
      if m && m[1]
        self.email = m[1].sub(/^[\.\-\_]+/, '')
      end
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

  def full_name=(value)
    value.strip! if value.present?
    write_attribute(:full_name, value)
  end

  def bio=(value)
    value.strip! if value.present?
    write_attribute(:bio, value)
  end

  def website=(value)
    value = value.strip.downcase if value.present?
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
      retries = 0
      begin
        client = InstaClient.new.client
        # looking for username via search
        resp = client.user_search(self.username)
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::BadRequest, Instagram::InternalServerError, Instagram::GatewayTimeout,
        JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
        logger.info "#{">> issue".red} #{e.class.name} :: #{e.message}"
        retries += 1
        sleep 10*retries
        retry if retries <= 5
        raise e
      end

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
          # set random username for it, later we will start update_info to get actual username
          exists_username.username = "#{exists_username.username}#{Time.now.to_i}"
          exists_username.save
        end
      end
    rescue Instagram::BadRequest => e
      if e.message =~ /you cannot view this resource/

        self.private = true

        # if user is private and we don't have it's username, than just remove it from db
        if self.private? && self.username.blank?
          self.destroy
          return false
        end

        self.grabbed_at = Time.now

        # If account private - try to get info from public page via http
        resp = self.update_via_http!
        return false unless resp

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
      JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Faraday::ParsingError, Zlib::BufError, Errno::EPIPE => e
      retries += 1
      sleep 10*retries
      retry if retries <= 5
      raise e
    end

    self.set_data data
    self.grabbed_at = Time.now
    self.private = false if self.private?
    self.save

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
      resp = Faraday.new(:url => 'http://instagram.com') do |f|
        f.use FaradayMiddleware::FollowRedirects
        f.adapter :net_http
      end.get("/#{self.username}/") do |req|
        req.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36"
      end
    rescue Faraday::ConnectionFailed, Errno::ETIMEDOUT => e
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
    data = json['entry_data']['UserProfile'].first['user']

    self.set_data data
    self.save
  end

  # What the avg interval between followers
  #
  # @return [Float] how often new user following current user, in seconds what avg time between followers
  #
  def follow_speed
    dates = self.user_followers.ne(followed_at: nil).order_by(followed_at: :asc).pluck(:followed_at)
    ((dates.last - dates.first) / dates.size.to_f).round(2)
  end

  def update_followers_batch *args
    self.update_info! force: true

    if self.followed_by < 2_000
      UserFollowersWorker.perform_async self.id
      return true
    end

    if self.user_followers.ne(followed_at: nil).size > 2
      speed = self.follow_speed
    else
      speed = 2_000
    end

    puts "Speed: #{speed}"

    jobs = []

    start = Time.now.to_i
    amount = (self.followed_by/1_000).ceil
    amount.times do |i|
      start_cursor = start-i*speed*100
      finish_cursor = i+1 < amount ? start-(i+1)*speed*100 : nil
      jobs << UserFollowersWorker.perform_async(self.id, start_cursor: start_cursor, finish_cursor: finish_cursor, ignore_exists: true)
    end

    jobs
  end

  # Updating list of all followers for current user
  #
  # @example
  #   User.get('anton_zaytsev').update_followers continue: true
  #
  # @option options :reload [Boolean] default: false, if reload is set to true,
  #     code will download whole list of followers and replace exists list by new one
  # @option options :deep [Boolean] default: false, if need to updated info for each added user in background
  # @option options :ignore_exists [Boolean] default: false, iterates over all followers list
  # @option options :start_cursor [Integer] start time for followers lookup in seconds (timestamp)
  # @option options :finish_cursor [Integer] end time for followers lookup in seconds (timestamp)
  # @option options :continue [Boolean] find oldest follower and start looking for followers from it, by default: false
  # @option options :count [Integer] amount of users requesting from Instagram per request
  # @option options :skip_exists [Boolean] skip exists
  #
  # @note
  #   Script stops if found more than 5 exists followers from list in database
  #
  def update_followers *args
    options = args.extract_options!
    return false if self.insta_id.blank?

    options = options.inject({}){|obj, (k, v)| obj[k.to_sym] = v; obj} # convert all string keys to symbols

    cursor = options[:start_cursor] ? options[:start_cursor].to_f.round(3).to_i * 1_000 : nil
    finish_cursor = options[:finish_cursor] ?  options[:finish_cursor].to_f.round(3).to_i * 1_000 : nil

    self.update_info!

    return false if self.destroyed? || self.private?

    logger.debug ">> [#{self.username.green}] followed by: #{self.followed_by}"

    if options[:continue]
      last_follow_time = Follower.where(user_id: self.id).ne(followed_at: nil).order(followed_at: :asc).only(:followed_at).first
      if last_follow_time
        cursor = last_follow_time.followed_at.to_i * 1_000
      end
    end

    options[:count] ||= 100

    if options[:reload]
      Follower.where(user_id: self.id).destroy_all
    end

    followers_ids = []
    total_exists = 0
    total_added = 0
    skipped = false

    while true
      start = Time.now

      exists = 0
      added = 0
      retries = 0

      begin
        client = InstaClient.new
        resp = client.client.user_followed_by self.insta_id, cursor: cursor, count: options[:count]
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::InternalServerError,
             Instagram::GatewayTimeout, JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError,
             Errno::EPIPE => e
        Rails.logger.info e.message
        sleep 10*retries
        retries += 1
        retry if retries <= 5
      rescue Instagram::BadRequest => e
        Rails.logger.info e.message
        if e.message =~ /you cannot view this resource/
          break
        elsif e.message =~ /this user does not exist/
          self.destroy
          return false
        elsif e.message =~ /The access_token provided is invalid/
          client.login.destroy
          retry
        end
        raise e
      end

      end_ig = Time.now

      users = User.in(insta_id: resp.data.map{|el| el['id']}).to_a
      fols = Follower.where(user_id: self.id).in(follower_id: users.map(&:id)).to_a

      resp.data.each do |user_data|
        logger.debug "Row #{user_data['username']} start"
        row_start = Time.now

        new_record = false

        user = users.select{|el| el.insta_id == user_data['id'].to_i}.first
        unless user
          user = User.new insta_id: user_data['id']
          new_record = true
        end

        # some unexpected behavior
        if user.insta_id.present? && user_data['id'].present? && user.insta_id != user_data['id'].to_i
          raise Exception
        end

        user.set_data user_data

        UserWorker.perform_async(user.id, true) if options[:deep]

        user.must_save if user.changed?

        followers_ids << user.id

        # if request is first, withour cursor
        followed_at = Time.now
        # cursor is kind of timestamp
        followed_at = Time.at(cursor.to_i/1000) if cursor

        if new_record
          Follower.create(user_id: self.id, follower_id: user.id, followed_at: followed_at)
          added += 1
        else
          fol = Follower.where(user_id: self.id, follower_id: user.id)

          if options[:reload]
            fol.first_or_initialize
            if fol.followed_at.blank? || fol.followed_at > followed_at
              fol.followed_at = followed_at
              fol.save
            end
            added += 1
          else
            fol_exists = fols.select{|el| el.follower_id == user.id }.first

            if fol_exists
              if fol_exists.followed_at.blank? || fol_exists.followed_at > followed_at
                fol_exists.followed_at = followed_at
                fol_exists.save
              end
              exists += 1
            else
              fol = fol.first_or_initialize
              if fol.new_record?
                fol.followed_at = followed_at
                fol.save
                added += 1
              else
                if fol.followed_at.blank? || fol.followed_at > followed_at
                  fol.followed_at = followed_at
                  fol.save
                end
                exists += 1
              end
            end
          end
        end

        logger.debug "Row #{user_data['username']} end / time: #{(Time.now - row_start).round(2)}s"
      end

      total_exists += exists
      total_added += added

      finish = Time.now
      logger.debug ">> [#{self.username.green}] followers:#{self.followed_by} request: #{(finish-start).to_f.round(2)}s :: IG request: #{(end_ig-start).to_f.round(2)}s / exists: #{exists} (#{total_exists.to_s.light_black}) / added: #{added} (#{total_added.to_s.light_black})"

      if exists > 5
        if options[:skip_exists] && !skipped
          last_follow_time = Follower.where(user_id: self.id).ne(followed_at: nil).order(followed_at: :asc).first
          if last_follow_time
            cursor = last_follow_time.followed_at.to_i * 1_000
            skipped = true
            next
          end
        end
      end

      break if !options[:ignore_exists] && exists > 5

      cursor = resp.pagination['next_cursor']

      unless cursor
        if !options[:reload] && !skipped
          current_followers = Follower.where(user_id: self.id).pluck(:follower_id)
          unfollowed = current_followers - followers_ids
          if unfollowed.size > 0
            Follower.where(user_id: self.id).in(follower_id: unfollowed).destroy_all
          end
        end
        self.delete_duplicated_followers!
        break
      end

      if finish_cursor && cursor.to_i < finish_cursor
        Rails.logger.info "#{"Stopped".red} by finish_cursor point finish_cursor: #{Time.at(finish_cursor/1000)} (#{finish_cursor}) / cursor: #{Time.at(cursor.to_i/1000)} (#{cursor}) / added: #{total_added}"
        break
      end
    end

    self.save if self.changed?

    true
  end

  def user_followers
    Follower.where(user_id: self.id)
  end

  def followers
    User.in(id: self.user_followers.pluck(:follower_id))
  end

  def followers_size
    self.user_followers.size
  end

  def update_followers_async
    ProcessFollowersWorker.spawn self.id
  end

  def delete_duplicated_followers!
    followers_ids = Follower.where(user_id: self.id).pluck(:follower_id)
    return true if followers_ids.size == followers_ids.uniq.size
    dups = followers_ids.inject({}){ |obj, el| obj[el] ||= 0; obj[el] += 1; obj }.select{ |k, v| v > 1 }
    dups.each do |k, v|
      Follower.where(user_id: self.id, follower_id: k).limit(v-1).destroy_all
    end
  end

  # Update list of all profiles user follow
  #
  # @example
  #   User.get('anton_zaytsev').update_followees continue: true
  #
  # @option options :reload [Boolean] default: false, if reload is set to true,
  #     code will download whole list of followers and replace exists list by new one
  # @option options :deep [Boolean] default: false, if need to updated info for each added user in background
  # @option options :ignore_exists [Boolean] default: false, iterates over all followees list
  # @option options :start_cursor [Integer] start time for followers lookup in seconds (timestamp)
  # @option options :finish_cursor [Integer] end time for followers lookup in seconds (timestamp)
  # @option options :continue [Boolean] find oldest follower and start looking for followers from it, by default: false
  # @option options :count [Integer] amount of users requesting from Instagram per request
  #
  # @note
  #   Script stops if found more than 5 exists followers from list in database
  #
  def update_followees *args
    options = args.extract_options!
    return false if self.insta_id.blank?

    options = options.inject({}){|obj, (k, v)| obj[k.to_sym] = v; obj} # convert all string keys to symbols

    cursor = options[:start_cursor] ? options[:start_cursor].to_f.round(3).to_i * 1_000 : nil
    finish_cursor = options[:finish_cursor] ?  options[:finish_cursor].to_f.round(3).to_i * 1_000 : nil

    self.update_info!

    return false if self.destroyed? || self.private?

    logger.debug ">> [#{self.username.green}] follows: #{self.follows}"

    if options[:continue]
      last_follow_time = Follower.where(follower_id: self.id).not(followed_at: nil).order(followed_at: :asc).first
      if last_follow_time
        cursor = last_follow_time.followed_at.to_i * 1_000
      end
    end

    options[:count] ||= 100

    if options[:reload]
      Follower.where(follower_id: self.id).destroy_all
    end

    followees_ids = []
    total_exists = 0
    total_added = 0

    while true
      start = Time.now

      exists = 0
      added = 0
      retries = 0

      begin
        client = InstaClient.new.client
        resp = client.user_follows self.insta_id, cursor: cursor, count: options[:count]
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::InternalServerError,
        Instagram::GatewayTimeout, JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError,
        Errno::EPIPE => e
        Rails.logger.info e.message
        sleep 10*retries
        retries += 1
        retry if retries <= 5
      rescue Instagram::BadRequest => e
        Rails.logger.info e.message
        if e.message =~ /you cannot view this resource/
          break
        elsif e.message =~ /this user does not exist/
          self.destroy
          return false
        end
        raise e
      end

      end_ig = Time.now

      users = User.in(insta_id: resp.data.map{|el| el['id']}).to_a
      fols = Follower.where(follower_id: self.id).in(user_id: users.map(&:id)).to_a

      resp.data.each do |user_data|
        logger.debug "Row #{user_data['username']} start"
        row_start = Time.now

        new_record = false

        user = users.select{|el| el.insta_id == user_data['id'].to_i}.first
        unless user
          user = User.new insta_id: user_data['id']
          new_record = true
        end

        # some unexpected behavior
        if user.insta_id.present? && user_data['id'].present? && user.insta_id != user_data['id'].to_i
          raise Exception
        end

        user.set_data user_data

        UserWorker.perform_async(user.id, true) if options[:deep]

        user.must_save if user.changed?

        followees_ids << user.id

        followed_at = Time.now
        followed_at = Time.at(cursor.to_i/1000) if cursor

        if new_record
          Follower.create(follower_id: self.id, user_id: user.id, followed_at: followed_at)
          added += 1
        else
          fol = Follower.where(follower_id: self.id, user_id: user.id)

          if options[:reload]
            fol.first_or_initialize
            if fol.followed_at.blank? || fol.followed_at > followed_at
              fol.followed_at = followed_at
              fol.save
            end
            added += 1
          else
            fol_exists = fols.select{|el| el.user_id == user.id }.first

            if fol_exists
              if fol_exists.followed_at.blank? || fol_exists.followed_at > followed_at
                fol_exists.followed_at = followed_at
                fol_exists.save
              end
              exists += 1
            else
              fol = fol.first_or_initialize
              if fol.new_record?
                fol.followed_at = followed_at
                fol.save
                added += 1
              else
                if fol.followed_at.blank? || fol.followed_at > followed_at
                  fol.followed_at = followed_at
                  fol.save
                end
                exists += 1
              end
            end
          end
        end

        logger.debug "Row #{user_data['username']} end / time: #{(Time.now - row_start).round(2)}s"
      end

      total_exists += exists
      total_added += added

      finish = Time.now
      logger.debug ">> [#{self.username.green}] followees:#{self.follows} request: #{(finish-start).to_f.round(2)}s :: IG request: #{(end_ig-start).to_f.round(2)}s / exists: #{exists} (#{total_exists.to_s.light_black}) / added: #{added} (#{total_added.to_s.light_black})"

      break if !options[:ignore_exists] && exists >= 5

      cursor = resp.pagination['next_cursor']

      unless cursor
        unless options[:reload]
          current_followees = Follower.where(follower_id: self.id).pluck(:user_id)
          left = current_followees - followees_ids
          if left.size > 0
            Follower.where(follower_id: self.id).in(user_id: left).destroy_all
          end
        end
        break
      end

      if finish_cursor && cursor.to_i < finish_cursor
        Rails.logger.info "#{"Stopped".red} by finish_cursor point finish_cursor: #{Time.at(finish_cursor/1000)} (#{finish_cursor}) / cursor: #{Time.at(cursor.to_i/1000)} (#{cursor}) / added: #{total_added}"
        break
      end
    end

    self.save

    true
  end

  def user_followees
    Follower.where(follower_id: self.id)
  end

  def followees
    User.in(id: self.user_followees.pluck(:user_id))
  end

  def followees_size
    self.user_followees.size
  end

  def set_data data
    self.full_name = data['full_name'] unless data['full_name'].nil?
    self.username = data['username']
    self.bio = data['bio'] unless data['bio'].nil?
    self.website = data['website'] unless data['website'].nil?
    self.insta_id = data['id'] if self.insta_id.blank?

    if data['counts'].present?
      self.media_amount = data['counts']['media'] if data['counts']['media'].present?
      self.followed_by = data['counts']['followed_by'] if data['counts']['followed_by'].present?
      self.follows = data['counts']['follows'] if data['counts']['follows'].present?
    end
  end

  def self.add_by_username username
    return false if username.blank? || username.size > 30 || username !~ /\A[a-zA-Z0-9\._]+\z/

    username.downcase!

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

    if username.numeric? && username.to_i > 0
      User.where(insta_id: username).first_or_create
    else
      username = username.to_s.strip.downcase
      User.add_by_username(username)
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

    self.update_info! unless self.insta_id
    raise Exception unless self.insta_id || self.destroyed?
    return false if self.private?

    while true
      time_start = Time.now
      retries = 0
      begin
        client = InstaClient.new
        media_list = client.client.user_recent_media self.insta_id, count: 100, max_id: max_id
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::InternalServerError,
             Instagram::GatewayTimeout, JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError,
             Errno::EPIPE => e
        retries += 1
        sleep 10*retries
        retry if retries <= 5
        raise e
      rescue Instagram::BadRequest => e
        # looks likes account became private
        if e.message =~ /you cannot view this resource/
          self.update_info! force: true
          break
        elsif e.message =~ /this user does not exist/
          self.destroy
          return false
        elsif e.message =~ /The access_token provided is invalid/
          client.login.destroy
          retry
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
        logger.debug "#{">>".green} Start process #{media_item['id']}"
        ts = Time.now

        media = media_found.select{|el| el.insta_id == media_item['id']}.first
        unless media
          media = Media.new(insta_id: media_item['id'], user_id: self.id)
          added += 1
        end

        media.set_data media_item
        media.tag_names = media_item['tags']

        media.save if media.changed?

        media.set_tags media_item['tags'], tags_found
        tags_found.concat(media.tags.to_a).uniq!

        avg_created_time += media['created_time'].to_i

        logger.debug "#{">>".green} End process #{media_item['id']}. T:#{(Time.now - ts).to_f.round(2)}s"
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
    user = self.where(username: username).ne(insta_id: exists_insta_id).first
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
      user = User.where(website: /#{url}/).first
      users2 << user if user
    end

  end

  def update_location! *args
    options = args.extract_options!

    if self.location_updated_at && self.location_updated_at > 1.month.ago && self.location_country && !options[:force]
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

    self.location_country = country && country[0]
    self.location_state = state && state[0].join(', ')
    self.location_city = city && city[0].join(', ')
    self.location_updated_at = Time.now
    self.save

    self.location
  end

  alias :popular_location :update_location!

  def location
    {
      country: self.location_country,
      state: self.location_state,
      city: self.location_city,
    }
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

        data = Media.where(user_id: self.id).where(:location_lat.ne => nil, :location_tag.ne => '').group_by{ |m| m.location_country }
        amounts = []
        data.each{ |k, v| amounts << [k, v.size] }
        amounts = amounts.sort{ |a, b| a[1] <=> b[1] }.reverse

        unless amounts[0][0].nil? && with_location_amount > 20
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

    self.update_info! unless self.insta_id

    media = self.media.order(created_time: :desc).lt(created_time: 1.day.ago).limit(media_limit)

    if media.size < options[:total_limit]
      Rails.logger.info "[#{"Update AVG Data".green}] [#{self.username.cyan}] Grabbing more media, current: #{media.size}"
      self.recent_media ignore_exists: true, total_limit: options[:total_limit]
      media = self.media.order(created_time: :desc).lt(created_time: 1.day.ago).limit(media_limit)
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
    users = User.in(username: usernames).to_a

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
    users = User.in(username: usernames).pluck(:id, :username)

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
    record.save

    true
  end

  def must_save
    self.save

    unless self.valid?
      if self.errors.messages[:insta_id]
        return User.where(username: self.username).first
      elsif self.errors.messages[:username]
        exists_user = User.where(username: self.username).first

        if exists_user.insta_id == self.insta_id
          return exists_user
        else
          exists_user.update_info!
          if exists_user.private? || exists_user.username == self.username
            exists_user.destroy
            self.save
          end
        end
      else
        raise Exception.new "Invalid user #{self.insta_id} / #{self.username}"
      end
    end

    self
  end

end
