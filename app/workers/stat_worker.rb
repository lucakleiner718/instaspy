class StatWorker

  def self.daily_stat
    Stat.create key: 'users_amount', value: User.all.size
    Stat.create key: 'media_amount', value: Media.all.size
    Stat.create key: 'tags_amount', value: Tag.all.size
  end

end