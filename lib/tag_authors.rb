class TagAuthors

  def self.get_all tag, timeframe
    users = []
    tag.media.where('created_at > ?', timeframe).includes(:user).each do |media|
      users << media.user
    end

    users.uniq!

    GeneralMailer.tag_authors(tag, users).deliver
  end

end