class Reporter

  def self.avg_likes_comments usernames

    data = []

    usernames.in_groups_of(1000, false).each do |usernames_group|
      users = User.where(username: usernames_group)

      if users.size < usernames_group.size
        find_usernames = usernames_group - users.pluck(:username)

        find_usernames.each do |u|
          user = User.where(username: u).first_or_create
          user.update_info!
          users << user if user.insta_id.present?
        end
      end

      users.each do |user|
        user.recent_media if user.media.where('likes_amount is not null and comments_amount is not null').size < 20

        media = user.media.order(created_time: :desc).where('created_time < ?', 1.day.ago)
        # media.where('likes_amount is not null or comments_amount is not null').limit(100).each{ |m| m.update_info! }

        avg_likes = media.where('likes_amount is not null').limit(20).pluck(:likes_amount).sum / media.size.to_f
        avg_comments = media.where('comments_amount is not null').limit(20).pluck(:comments_amount).sum / media.size.to_f

        data << [user, avg_likes, avg_comments]
      end

    end

    data

    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'AVG Likes', 'AVG Comments', 'Bio', 'Website', 'Follows', 'Followers', 'Media amount', 'Private account']
      data.each do |row|
        user = row[0]
        begin
          csv << [user.full_name, user.username, row[1].round(2), row[2].round(2), user.bio, user.website, user.follows, user.followed_by, user.media_amount, (user.private ? 'Yes' : 'No')]
        rescue Exception => e
        end
      end
    end

    GeneralMailer.avg_likes_comments(csv_string, usernames).deliver
  end

end