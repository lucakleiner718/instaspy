class User < ActiveRecord::Base

  has_many :media, class_name: 'Media', dependent: :destroy

  has_many :user_followers, class_name: 'Follower', foreign_key: :user_id, dependent: :destroy
  has_many :followers, through: :user_followers

  has_many :user_followees, class_name: 'Follower', foreign_key: :follower_id, dependent: :destroy
  has_many :followees, through: :user_followees

  belongs_to :feedly, primary_key: :website, foreign_key: :website

  scope :not_grabbed, -> { where grabbed_at: nil }
  scope :not_private, -> { where private: [nil, false] }
  scope :privates, -> { where private: true }
  scope :outdated, -> { where('grabbed_at is null OR grabbed_at < ? OR bio is null OR website is null OR follows is null OR followed_by is null OR media_amount IS NULL', 7.days.ago) }
  scope :with_url, -> { where 'website is not null && website != ""' }
  scope :without_likes, -> { where('avg_likes IS NULL OR avg_likes_updated_at is null OR avg_likes_updated_at < ?', 1.month.ago) }
  scope :without_location, -> { where('location_updated_at IS NULL OR location_updated_at < ?', 3.months.ago) }
  scope :with_media, -> { where('media_amount > 0').where(private: false) }

  before_save do
    # Catch email from bio
    if self.bio.present?
      email_regex = /([\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+)/
      m = self.bio.downcase.match(email_regex)
      if m && m[1]
        self.email = m[1].sub(/^[\.\-\_]+/, '')
      end
    end

    if self.username_changed?
      self.username = self.username.strip.gsub(/\s/, '')

      if self.insta_id.present?
        User.fix_exists_username(self.username, self.insta_id)
      end
    end

    if self.email_changed? && self.email.present?
      self.email = self.email.downcase
    end

    # if self.website_changed? && self.website.present? && self.feedly_feed_id.blank? && self.feedly_updated_at.present?
    #   self.feedly_updated_at = nil
    # end
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
      JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError, Errno::EPIPE => e
      retries += 1
      sleep 10*retries
      retry if retries <= 5
      raise e
    end

    self.insta_data data
    self.grabbed_at = Time.now
    self.private = false if self.private?
    self.save

    if exists_username
      exists_username.update_info!
      exists_username.destroy if exists_username.private?
    end

    true
  end

  def update_via_http!
    retries = 0
    begin
      resp = Curl::Easy.perform("http://instagram.com/#{self.username}/") do |curl|
        curl.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36"
        curl.verbose = Rails.env.development?
        curl.follow_location = true
      end
    rescue Curl::Err::HostResolutionError, Curl::Err::SSLConnectError, Curl::Err::GotNothingError,
      Curl::Err::TimeoutError => e
      retries += 1
      sleep 10*retries
      retry if retries <= 5
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
    shared_data_element = html.xpath('//script[contains(text(), "_sharedData")]').first
    return false unless shared_data_element
    content = shared_data_element.text.sub('window._sharedData = ', '').sub(/;$/, '')
    json = JSON.parse content
    data = json['entry_data']['UserProfile'].first['user']

    self.insta_data data
    self.save
  end

  # what the avg interval between followers
  def follow_speed
    dates = self.user_followers.where('followed_at is not null').order(followed_at: :asc).pluck(:followed_at)
    ((dates.last - dates.first) / dates.size.to_f).round(2)
  end

  def update_followers_batch *args
    self.update_info! force: true

    if self.followed_by < 2_000
      UserFollowersWorker.perform_async self.id
      return true
    end

    if self.user_followers.where('followed_at is not null').size > 2
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
      # puts "#{Time.at(start_cursor)} - #{Time.at(finish_cursor) if finish_cursor}"
      jobs << UserFollowersWorker.perform_async(self.id, start_cursor: start_cursor, finish_cursor: finish_cursor, ignore_exists: true)
      # a = Follower.where(user_id: self.id).where('followed_at < ?', Time.at(start_cursor.to_i))
      # a = a.where('followed_at >= ?', Time.at(finish_cursor.to_i)) if finish_cursor
      # puts "#{i}: #{a.size}"
    end

    jobs
  end

  # Script stops if found more than 5 exists followers from list in database
  # Params
  # reload (boolean) - default: false, if reload is set to true, code will download whole list of followers and replace exists list by new one
  # deep (boolean) - default: false, if need to updated info for each added user in background
  # ignore_exists (boolean) - default: false, iterates over all followers list
  # start_cursor (timestamp) - start time for followers lookup
  # finish_cursor (timestamp) - end time for followers lookup
  # continue (boolean) - find oldest follower and start looking for followers from it
  def update_followers *args
    return false if self.insta_id.blank?

    options = args.extract_options!
    options = Hash[options.map{ |k, v| [k.to_sym, v] }] # convert all string keys to symbols

    cursor = options[:start_cursor] ? options[:start_cursor].to_f.round(3).to_i * 1_000 : nil
    finish_cursor = options[:finish_cursor] ?  options[:finish_cursor].to_f.round(3).to_i * 1_000 : nil

    self.update_info!

    return false if self.destroyed? || self.private?

    followed = self.followed_by
    logger.debug ">> [#{self.username.green}] followed by: #{followed}"

    if options[:continue]
      last_follow_time = Follower.where(user_id: self.id).where('followed_at is not null').order(followed_at: :asc).first
      if last_follow_time
        cursor = last_follow_time.followed_at.to_i * 1_000
      end
    end

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
        resp = client.user_followed_by self.insta_id, cursor: cursor, count: 100
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

      users = User.where(insta_id: resp.data.map{|el| el['id']})
      fols = Follower.where(user_id: self.id, follower_id: users.map{|el| el.id}).to_a

      # follower_ids_list = Follower.where(user_id: self.id).pluck(:follower_id)

      resp.data.each do |user_data|
        logger.debug "Row #{user_data['username']} start"
        row_start = Time.now

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

        UserWorker.perform_async(user.id, true) if options[:deep]

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

        followed_at = Time.now
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

        # unless follower_ids_list.include?(user.id)
        #   follower_ids_list << user.id
        # end

        logger.debug "Row #{user_data['username']} end / time: #{(Time.now - row_start).round(2)}s"
      end

      total_exists += exists
      total_added += added

      finish = Time.now
      # logger.debug ">> [#{self.username.green}] followers:#{follower_ids_list.size}/#{followed} request: #{(finish-start).to_f.round(2)}s :: IG request: #{(end_ig-start).to_f.round(2)}s / exists: #{exists} (#{total_exists.to_s.light_black}) / added: #{added} (#{total_added.to_s.light_black})"
      logger.debug ">> [#{self.username.green}] followers:#{followed} request: #{(finish-start).to_f.round(2)}s :: IG request: #{(end_ig-start).to_f.round(2)}s / exists: #{exists} (#{total_exists.to_s.light_black}) / added: #{added} (#{total_added.to_s.light_black})"

      break if !options[:ignore_exists] && exists >= 5

      cursor = resp.pagination['next_cursor']

      break unless cursor

      if finish_cursor && cursor.to_i < finish_cursor
        Rails.logger.info "#{"Stopped".red} by finish_cursor point finish_cursor: #{Time.at(finish_cursor/1000)} (#{finish_cursor}) / cursor: #{Time.at(cursor.to_i/1000)} (#{cursor}) / added: #{total_added}"
        break
      end
    end

    self.save

    true
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
        elsif e.message =~ /this user does not exist/
          self.destroy
          return false
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
          user.save if user.new_record? || user.changed?
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
      User.where(insta_id: username).first_or_create
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
        end
        raise e
      end

      ig_time_end = Time.now

      added = 0
      avg_created_time = 0

      data = media_list.data

      media_found = Media.where(insta_id: data.map{|el| el['id']})
      tags_found = Tag.where(name: data.map{|el| el['tags']}.flatten.uniq).select(:id, :name).to_a

      data.each do |media_item|
        logger.debug "#{">>".green} Start process #{media_item['id']}"
        ts = Time.now

        media = media_found.select{|el| el.insta_id == media_item['id']}.first
        unless media
          media = Media.new(insta_id: media_item['id'], user_id: self.id)
        end

        media.media_data media_item

        added += 1 if media.new_record?

        begin
          media.save
        rescue ActiveRecord::RecordNotUnique => e
          media = Media.where(insta_id: media_item['id']).first
        end

        media.media_tags media_item['tags'], tags_found
        tags_found.concat(media.tags.to_a).uniq!{|el| el.id}

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
    with_location = self.media.with_location
    with_location_amount = with_location.size
    processed = 0

    with_location.where('location_country is null').each_with_index do |media, index|
      processed += 1
      # if user obviously have lots of media in one place, leave other media
      if index % 5 == 0
        resp = Tag.connection.execute("SELECT count(id), location_country FROM `media`  WHERE `media`.`user_id` = #{self.id} AND (location_lat is not null and location_lat != '') GROUP BY location_country").to_a

        # if we don't have media where location_country is blank
        without_country_amount = resp.select{ |el| el[1].nil? }.first.try(:first)

        break if without_country_amount.blank?

        # if we have at least 10% of same location
        if with_location_amount > 20 && without_country_amount / with_location_amount.to_f < 0.9
          # if resp.size == 2
          logger.debug ">> update_media_location: #{self.username.green}. stopped because most of the media has same country"
          break
          # else
            # binding.pry
            # raise
          # end
        end
      end

      media.update_location!

      logger.debug ">> update_media_location: #{self.username.green}. progress: #{(processed / with_location_amount.to_f * 100).to_i}%"

      sleep(5)
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

    media = self.media.order(created_time: :desc).where('created_time < ?', 1.day.ago).limit(media_limit)

    if media.size < options[:total_limit]
      Rails.logger.info "[#{"Update AVG Data".green}] [#{self.username.cyan}] Grabbing more media, current: #{media.size}"
      self.recent_media ignore_exists: true, total_limit: options[:total_limit]
      media = self.media.order(created_time: :desc).where('created_time < ?', 1.day.ago).limit(media_limit)
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

  def get_feedly
    return false if self.website.blank?
    f = Feedly.where('feedly_url = :w OR website = :w', w: self.website).first
    unless f
      f = Feedly.process self.website
    end
    f
  end

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

end
