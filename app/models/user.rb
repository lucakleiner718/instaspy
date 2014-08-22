class User < ActiveRecord::Base

  has_many :media

  before_save do
    # if self.full_name_changed?
      self.full_name = self.full_name.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: '')
      self.full_name = self.full_name.encode(self.full_name.encoding, "binary", invalid: :replace, undef: :replace, replace: '')
    # end

    # if self.bio_changed?
      self.bio = self.bio.encode( "UTF-8", "binary", invalid: :replace, undef: :replace, replace: '')
      self.bio = self.bio.encode(self.bio.encoding, "binary", invalid: :replace, undef: :replace, replace: '')
    # end
  end

  def self.update_info
    User.where("bio is NULL OR website is NULL OR full_name is NULL").each do |u|
      u.update_info!
    end
  end

  def update_info!
    client = Instagram.client(:access_token => Setting.g('instagram_access_token'))
    begin
      data = client.user(self.insta_id)
    rescue
      return false
    end
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
