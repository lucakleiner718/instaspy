class User < ActiveRecord::Base

  has_many :media, class_name: 'Media', dependent: :destroy

  has_many :user_followers, class_name: 'Follower', foreign_key: :user_id, dependent: :destroy
  has_many :followers, through: :user_followers

  has_many :user_followees, class_name: 'Follower', foreign_key: :follower_id, dependent: :destroy
  has_many :followees, through: :user_followees

  scope :not_grabbed, -> { where grabbed_at: nil }
  scope :not_private, -> { where private: [nil, false] }
  scope :privates, -> { where private: true }

  before_save do
    if self.full_name_changed?
      self.full_name = self.full_name.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.full_name = self.full_name.encode(self.full_name.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.full_name.strip!
    end

    if self.bio_changed?
      self.bio = self.bio.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.bio = self.bio.encode(self.bio.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.bio.strip!
    end

    if self.website_changed?
      self.website = self.website.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.website = self.website.encode(self.website.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.website = self.website[0, 255]
    end

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
    end
  end

  def self.update_info
    User.all.each do |u|
      u.update_info!
    end
  end

  def update_info!
    client = InstaClient.new.client

    if self.insta_id.blank? && self.username.present?
      resp = client.user_search(self.username)

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

    #   if self.insta_id.blank?
    #     exists = User.where(insta_id: data['id']).first
    #     if exists
    #       exists.username = self.username
    #       exists.save
    #       self.destroy
    #       return false
    #     end
    #   end
    #
      if data
        self.insta_data data
      else
        self.destroy
        return false
      end
    end

    exists_username = nil

    begin
      raise if self.insta_id.blank?
      info = client.user(self.insta_id)
      data = info.data

      if data['username'] != self.username
        exists_username = User.where(username: data['username']).first
        if exists_username
          exists_username.username = nil
          exists_username.save
        end
      end
    rescue Instagram::BadRequest => e
      if e.message =~ /you cannot view this resource/

        # if user is private and we don't have it's username, than just remove it from db
        if self.private && self.username.blank?
          self.destroy
          return false
        end

        if self.private && self.grabbed_at && self.grabbed_at > 7.days.ago
          return self
        end

        self.private = true
        self.grabbed_at = Time.now

        # If account private - try to get info from public page via http
        begin
          self.update_private_account
        rescue Exception => e
          # binding.pry
        end

        self.save
        return self
      elsif e.message =~ /this user does not exist/
        self.destroy
      end
      return false
    rescue Interrupt
      raise Interrupt
    rescue Exception => e
      # binding.pry
      return false
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

    exists_username.update_info! if exists_username

    self
  end

  def update_private_account
    url = "http://instagram.com/#{self.username}/"
    resp = Curl::Easy.perform(url) do |curl|
      curl.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36"
      curl.verbose = true
      curl.follow_location = true
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

  def self.get_info
    User.where('bio is null').order(created_at: :desc).find_each do |u|
      u.update_info!
    end
  end

  def self.update_worker
    User.not_grabbed.not_private.order(created_at: :desc).limit(1000).each { |u| u.update_info! }
    # User.not_grabbed.not_private.limit(1000).each do |u|
    #   u.update_info!
    # end
  end

  def followers_size
    client = InstaClient.new.client
    begin
      user_data = client.user(self.insta_id)['data']
      user_data['counts']['followed_by']
    rescue Instagram::BadRequest => e
      if e.message =~ /you cannot view this resource/
        self.private = true
        self.grabbed_at = Time.now
        self.save
      elsif e.message =~ /this user does not exist/
        self.destroy
      end
      return false
    rescue
      return false
    end
  end

  def followees_size
    return false if self.private?

    client = InstaClient.new.client
    begin
      user_data = client.user(self.insta_id)['data']
      user_data['counts']['follows']
    rescue Instagram::BadRequest => e
      if e.message =~ /you cannot view this resource/
        self.private = true
        self.grabbed_at = Time.now
        self.save
      elsif e.message =~ /this user does not exist/
        self.destroy
      end
      return false
    rescue
      return false
    end
  end

  def update_followers *args
    return false if self.insta_id.blank?

    options = args.extract_options!

    client = InstaClient.new.client
    next_cursor = nil

    user_data = client.user(self.insta_id)['data']
    followed = user_data['counts']['followed_by']
    puts "#{self.username} followed by: #{followed}"

    exists = 0
    if options[:reload]
      self.follower_ids = []
    end

    follower_ids = []
    begining_time = Time.now

    while true
      start = Time.now
      resp = client.user_followed_by self.insta_id, cursor: next_cursor, count: 100
      next_cursor = resp.pagination['next_cursor']

      users = User.where(insta_id: resp.data.map{|el| el['id']})
      fols = Follower.where(user_id: self.id, follower_id: users.map{|el| el.id})

      resp.data.each do |user_data|
        user = users.select{|el| el.insta_id == user_data['id'].to_i}.first
        unless user
          user = User.new(insta_id: user_data['id'])
        end

        user.insta_data user_data

        if options[:deep] && !user.private && (user.updated_at.blank? || user.updated_at < 1.month.ago || user.website.nil? || user.follows.blank? || user.followed_by.blank? || user.media_amount.blank?)
          user.update_info!
        end

        new_record = user.new_record?

        user.save

        # fol = nil
        #
        # if new_record
        #   fol = fols.select{|el| el.follower_id == user.id }.first
        # end
        #
        # unless fol
        fol = Follower.where(user_id: self.id, follower_id: user.id)
        # end

        if options[:reload]
          fol.first_or_create
        else
          if fol.size == 1
            exists += 1
          else
            fol.first_or_create
          end
        end
        follower_ids << user.id

        user = nil # trying to save some RAM but nulling variable
      end

      resp = nil

      puts "followers:#{follower_ids.size}/#{followed} request:#{(Time.now-start).to_f}s left:#{((Time.now - begining_time).to_f/follower_ids.size * (followed-follower_ids.size)).to_i}s"

      puts "exists: #{exists}"

      break if !options[:ignore_exists] && exists >= 5
      break unless next_cursor
    end

    self.save
  end

  def update_followees *args

    return false if self.insta_id.blank? || self.private?

    options = args.extract_options!

    client = InstaClient.new.client
    next_cursor = nil

    begin
      user_data = client.user(self.insta_id)['data']
    rescue Instagram::BadRequest => e
      if e.message =~ /you cannot view this resource/
        self.private = true
        self.grabbed_at = Time.now
        self.save
      # elsif e.message =~ /this user does not exist/
      #   self.destroy
      end
      return false
    rescue
      return false
    end

    follows = user_data['counts']['follows']
    puts "#{self.username} follows: #{follows}"

    return false if follows == 0

    exists = 0
    if options[:reload]
      self.followee_ids = []
    end

    followee_ids = []
    begining_time = Time.now

    while true
      start = Time.now
      resp = client.user_follows self.insta_id, cursor: next_cursor, count: 100
      next_cursor = resp.pagination['next_cursor']

      users = User.where(insta_id: resp.data.map{|el| el['id']})
      fols = Follower.where(follower_id: self.id, user_id: users.map{|el| el.id}) unless options[:reload]

      resp.data.each do |user_data|
        user = users.select{|el| el.insta_id == user_data['id'].to_i}.first
        unless user
          user = User.new(insta_id: user_data['id'])
        end

        user.insta_data user_data

        if options[:deep] && !user.private && (user.updated_at.blank? || user.updated_at < 1.month.ago || user.website.nil? || user.follows.blank? || user.followed_by.blank? || user.media_amount.blank?)
          user.update_info!
        end

        user.save if user.changed?

        fol = nil
        fol = fols.select{|el| el.user_id == user.id }.first unless options[:reload]
        fol = Follower.where(follower_id: self.id, user_id: user.id).first_or_initialize if fol.blank?

        if !options[:reload] && !fol.new_record?
          exists += 1
        end

        fol.save if fol.changed?

        followee_ids << user.id
      end

      puts "followers:#{followee_ids.size}/#{follows} request:#{(Time.now-start).to_f}s left:#{((Time.now - begining_time).to_f/followee_ids.size * (follows-followee_ids.size)).to_i}s"

      puts "exists: #{exists}"

      break if !options[:ignore_exists] && exists >= 5
      break unless next_cursor
    end

    self.save
  end

  def insta_data data
    self.username = data['username']
    self.bio = data['bio']
    self.website = data['website']
    self.full_name = data['full_name']
    self.insta_id = data['id']
  end

  def self.add_by_username username
    return false if username.blank? || username.size > 30 || username !~ /\A[a-zA-Z0-9\._]+\z/

    user = User.where(username: username).first_or_initialize

    return user if !user.new_record? && user.grabbed_at.present? && user.grabbed_at > 1.month.ago

    client = InstaClient.new.client
    begin
      resp = client.user_search(username)
    rescue Faraday::SSLError => e
      sleep(10)
      retry
    end

    data = nil
    data = resp.data.select{|el| el['username'].downcase == username.to_s.downcase }.first if resp.data.size > 0

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
      User.where('username = :id', id: username).first_or_create(username: username)
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

    while true
      client = InstaClient.new.client

      begin
        media_list = client.user_recent_media self.insta_id, count: 100, max_id: max_id
      rescue JSON::ParserError, Instagram::ServiceUnavailable, Instagram::BadGateway, Instagram::InternalServerError, Instagram::BadRequest, Faraday::ConnectionFailed => e
        break
      end

      added = 0
      avg_created_time = 0

      media_list.data.each do |media_item|
        media = Media.where(insta_id: media_item['id']).first_or_initialize(user_id: self.id)
        media.media_data media_item

        added += 1 if media.new_record?

        begin
          media.save
        rescue ActiveRecord::RecordNotUnique => e
        end

        avg_created_time += media['created_time'].to_i
      end

      break if media_list.data.size == 0

      total_added += added

      p "total_added: #{total_added}"

      avg_created_time = avg_created_time / media_list.data.size

      move_next = false

      break unless media_list.pagination.next_max_id

      if options[:created_from].present?
        if Time.at(avg_created_time) > options[:created_from]
          move_next = true
        end
      elsif total_added >= options[:total_limit]
        # stop
      elsif options[:ignore_added]
        move_next = true
      elsif added.to_f / media_list.data.size > 0.9
        move_next = true
      else
        break
      end

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

  before_save do
    if self.username_changed? && self.insta_id.present?
      User.fix_exists_username(self.username, self.insta_id)
    end
  end

  def self.fix_exists_username username, exists_insta_id
    user = self.where(username: username).where('insta_id != ?', exists_insta_id).first
    user.update_info! if user.present?
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

  def popular_location
    if self.location_updated_at && self.location_updated_at > 7.days.ago && self.location_country
      return {
        country: self.location_country,
        state: self.location_state,
        city: self.location_city,
      }
    end

    self.update_info! if !self.private? && (self.media_amount.blank? || !self.grabbed_at.present? || self.grabbed_at < 7.days.ago)

    return false if self.destroyed?

    media_amount = 50
    media_size = self.media.size

    # do not waste time on private
    if self.private && media_size == 0
      return false
    end

    # get some media, at least latest 50 posts
    if !self.private? && self.media_amount.present? && media_size < media_amount
      self.recent_media ignore_added: true, total_limit: media_amount
    end

    self.update_media_location

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
    {
      country: self.location_country,
      state: self.location_state,
      city: self.location_city,
    }
  end

  def update_media_location
    p "update_media_location: #{self.username}"
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

  def update_avg_data
    media = self.media.order(created_time: :desc).where('created_time < ?', 1.day.ago)

    likes_amount = 0
    comments_amount = 0
    media_amount = 0

    if media.size < 10
      self.recent_media total_limit: 50
    end

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
      p "Start #{row[0]}"
      user = User.add_by_username row[0]
      if user && user.email.blank?
        user.email = row[2]
        user.save
      end

      if user
        user.update_info! if user.followed_by.blank? || user.grabbed_at.blank? || user.grabbed_at < 1.week.ago
        added << [user.username, user.full_name, user.website, user.follows, user.followed_by, user.media_amount, user.email]
      end

      processed += 1

      p "Progress #{processed}/#{initial} (#{(processed/initial.to_f * 100).to_i}%)"
    end

    csv_string = CSV.generate do |csv|
      csv << ['Username', 'Full Name', 'Website', 'Follows', 'Followers', 'Media amount', 'Email']
      added.each do |row|
        csv << row
      end
    end

    p "Added #{added.size}"

    GeneralMailer.process_usernames_file(csv_string).deliver
  end

end
