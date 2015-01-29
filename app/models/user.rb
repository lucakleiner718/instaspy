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
    end

    if self.bio_changed?
      self.bio = self.bio.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.bio = self.bio.encode(self.bio.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
    end

    if self.website_changed?
      self.website = self.website.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.website = self.website.encode(self.website.encoding, "binary", invalid: :replace, undef: :replace, replace: ' ')
      self.website = self.website[0, 255]
    end

    if self.bio.present?
      email_regex = /([\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+)/
      m = self.bio.match(email_regex)
      if m && m[1]
        self.email = m[1].downcase.sub(/^[\.\-\_]+/, '')
      end
    end
  end

  def self.update_info
    User.all.each do |u|
      u.update_info!
    end
  end

  def update_info!
    client = InstaClient.new.client

    if self.username.present?
      resp = client.user_search(self.username)

      data = nil
      data = resp.data.select{|el| el['username'].downcase == username.downcase }.first if resp.data.size > 0

      if self.insta_id.blank?
        exists = User.where(insta_id: data['id']).first
        if exists
          exists.username = self.username
          exists.save
          self.destroy
          return false
        end
      end

      if data
        self.insta_data data
      else
        self.destroy
        return false
      end
    end

    begin
      info = client.user(self.insta_id)
      data = info.data
    rescue Instagram::BadRequest => e
      if e.message =~ /you cannot view this resource/
        self.private = true
        self.grabbed_at = Time.now

        # If account private - try to get info from public page via http
        begin
          if self.full_name.blank? || self.bio.blank? || self.website.blank?
            url = "https://instagram.com/#{self.username}/"
            resp = Curl::Easy.perform(url) do |curl|
              curl.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.93 Safari/537.36"
              curl.verbose = true
              curl.follow_location = true
            end
            html = Nokogiri::HTML(resp.body)
            content = html.search('script').select{|script| script.attr('src').blank? }.last.text.sub('window._sharedData = ', '').sub(/;$/, '')
            json = JSON.parse content
            user = json['entry_data']['UserProfile'].first['user']

            # self.full_name = resp.body.match(/"full_name":"([^"]+)"/)[1] if self.full_name.blank?
            self.full_name = user['full_name'] if self.full_name.blank?
            self.bio = user['bio'] if self.bio.blank?
            self.website = user['bio'] if self.website.blank?
            # self.media_amount = resp.body.match(/"media":(\d+)/)[1] if self.media_amount.blank?
            self.media_amount = user['counts']['media'] if self.media_amount.blank?
            # self.followed_by = resp.body.match(/"followed_by":(\d+)/)[1] if self.followed_by.blank?
            self.followed_by = user['counts']['followed_by'] if self.followed_by.blank?
            # self.follows = resp.body.match(/"follows":(\d+)/)[1] if self.follows.blank?
            self.follows = user['counts']['follows'] if self.follows.blank?
          end
        rescue
        end

        self.save
      elsif e.message =~ /this user does not exist/
        self.destroy
      end
      return false
    rescue
      # binding.pry
      return false
    end
    self.username = data['username']
    self.bio = data['bio']
    self.website = data['website']
    # self.profile_picture = data['profile_picture']
    self.full_name = data['full_name']
    self.followed_by = data['counts']['followed_by']
    self.follows = data['counts']['follows']
    self.media_amount = data['counts']['media']
    self.grabbed_at = Time.now if self.changed?
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
      # binding.pry
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
      # binding.pry
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
      # binding.pry
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
    user = User.where(username: username).first_or_initialize
    client = InstaClient.new.client
    resp = client.user_search(username)

    data = nil
    data = resp.data.select{|el| el['username'].downcase == username.to_s.downcase }.first if resp.data.size > 0

    exists = User.where(insta_id: data['id']).first
    if exists
      exists.username = data['username']
      exists.save
      return exists
    end

    if data
      user.insta_data data
      user.save
      user
    else
      false
    end
  end

  def self.get username
    if username.numeric?
      User.where('id = :id or insta_id = :id', id: username).first_or_create
    else
      User.where('username = :id', id: username).first_or_create
    end
  end

  def self.duplicates
    con = ActiveRecord::Base.connection()
    res = con.execute('select id,username from users')
    data = {}
    res.each {|el| data[el[1]] ||= 0; data[el[1]] += 1 }
    data.to_a.select{|el| el[1] > 1 }
  end

  def self.get_emails
    email_regex = /([\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+)/

    User.find_each(batch_size: 5000) do |user|
      next if user.bio.blank?
      m = user.bio.match(email_regex)
      if m && m[1]
        user.email = m[1].downcase.sub(/^[\.\-\_]+/, '')
        user.save
      end
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

    usernames.in_groups_of(1000, false) do |usernames_group|
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

  def recent_media
    client = InstaClient.new.client
    client.user_recent_media self.insta_id
  end

end
