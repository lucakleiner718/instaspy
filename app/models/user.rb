class User < ActiveRecord::Base

  has_many :media

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
      data = info['data']
    rescue Instagram::BadRequest => e
      if e.message =~ /you cannot view this resource/
        self.private = true
        self.save
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
    self.full_name = data['full_name'] if data['full_name'].present?
    self.followed_by = data['counts']['followed_by'] if data['counts']
    self.follows = data['counts']['follows'] if data['counts']
    self.media_amount = data['counts']['media'] if data['counts']
    self.grabbed_at = Time.now
    self.save
  end

  def self.get_info
    User.where('bio is null').order(created_at: :desc).find_each do |u|
      u.update_info!
    end
  end

  def self.update_worker
    User.not_grabbed.not_private.limit(1000).each do |u|
      u.update_info!
    end
  end

end
