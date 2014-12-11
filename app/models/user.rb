class User < ActiveRecord::Base

  has_many :media, class_name: 'Media', dependent: :destroy

  has_many :user_followers, class_name: 'Follower', foreign_key: :user_id, dependent: :destroy
  has_many :followers, through: :user_followers

  has_many :user_followees, class_name: 'Follower', foreign_key: :follower_id, dependent: :destroy
  has_many :followees, through: :user_followees

  scope :not_grabbed, -> { where grabbed_at: nil }
  scope :not_private, -> { where private: [nil, false] }

  before_save do
    if self.full_name_changed?
      self.full_name = self.full_name.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: '')
      self.full_name = self.full_name.encode(self.full_name.encoding, "binary", invalid: :replace, undef: :replace, replace: '')
    end

    if self.bio_changed?
      self.bio = self.bio.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: '')
      self.bio = self.bio.encode(self.bio.encoding, "binary", invalid: :replace, undef: :replace, replace: '')
    end

    if self.website_changed?
      self.website = self.website.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: '')
      self.website = self.website.encode(self.website.encoding, "binary", invalid: :replace, undef: :replace, replace: '')
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
      data = resp.data.select{|el| el['username'].downcase == username.downcase }.first if resp.data.size > 0

      if data
        user.insta_data data
        user.save
      else
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
    user_data = client.user(self.insta_id)['data']
    user_data['counts']['followed_by']
  end

  def followees_size
    client = InstaClient.new.client
    user_data = client.user(self.insta_id)['data']
    user_data['counts']['follows']
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

    return false if self.insta_id.blank?

    options = args.extract_options!

    client = InstaClient.new.client
    next_cursor = nil

    user_data = client.user(self.insta_id)['data']
    follows = user_data['counts']['follows']
    puts "#{self.username} follows: #{follows}"

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
      fols = Follower.where(follower_id: self.id, user_id: users.map{|el| el.id})

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
        # fol = fols.select{|el| el.user_id == user.id }.first
        fol = Follower.where(follower_id: self.id, user_id: user.id)
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
        followee_ids << user.id

        user = nil # trying to save some RAM but nulling variable
      end

      resp = nil

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
    data = resp.data.select{|el| el['username'].downcase == username.downcase }.first if resp.data.size > 0

    if data
      user.insta_data data
      user.save
      user
    else
      false
    end
  end

  def self.get username
    User.where('id = :id or insta_id = :id or username = :id', id: username).first_or_create(username: username)
  end

end
