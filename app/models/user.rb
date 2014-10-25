class User < ActiveRecord::Base

  has_many :media, class_name: 'Media', dependent: :destroy

  has_many :user_followers, class_name: 'Follower', foreign_key: :user_id
  has_many :followers, through: :user_followers

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

  def update_followers deep=false
    client = InstaClient.new.client
    next_cursor = nil
    followers = []

    while true
      resp = client.user_followed_by self.insta_id, cursor: next_cursor
      next_cursor = resp.pagination['next_cursor']

      resp.data.each do |user_data|
        user = User.where(insta_id: user_data['id']).first_or_initialize

        user.insta_data user_data

        if !user.private && deep && (user.updated_at.blank? || user.updated_at < 1.month.ago || user.website.nil? || user.follows.blank? || user.followed_by.blank? || user.media_amount.blank?)
          user.update_info!
        end

        user.save

        followers << user
      end

      break unless next_cursor
    end

    self.followers = followers
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
    if user.new_record?
      client = InstaClient.new.client
      resp = client.user_search(username)
      if resp.data.first
        user.insta_data resp.data.first
        user.save
      else
        return false
      end
    else
      user.insta_data resp.data.first
      user.save
    end
    user
  end

  def self.get id
    User.where('id = :id or insta_id = :id or username = :id', id: id).first
  end

end
