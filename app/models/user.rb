class User < ActiveRecord::Base

  has_many :media

  before_save do
    if self.full_name_changed?
      self.full_name = self.full_name.encode( "UTF-8", "binary", :invalid => :replace, :undef => :replace)
      self.full_name = self.full_name.encode(self.full_name.encoding, "binary", :invalid => :replace, :undef => :replace)
    end

    if self.bio_changed?
      self.bio = self.bio.encode( "UTF-8", "binary", :invalid => :replace, :undef => :replace)
      self.bio = self.bio.encode(self.bio.encoding, "binary", :invalid => :replace, :undef => :replace)
    end
  end

  def update_info!
    client = Instagram.client(:access_token => Setting.g('instagram_access_token'))
    data = client.user(self.insta_id)
    self.username = data['username']
    self.bio = data['bio']
    self.website = data['website']
    self.profile_picture = data['profile_picture']
    self.full_name = data['full_name']
    self.followed_by = data['counts']['followed_by']
    self.follows = data['counts']['follows']
    self.media_amount = data['counts']['media']
    self.save
  end

end
