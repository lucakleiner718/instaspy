class Reporter

  def self.avg_likes_comments usernames

    data = []
    processed = 0

    usernames.in_groups_of(1000, false).each do |usernames_group|
      users = User.where(username: usernames_group).to_a

      if users.size < usernames_group.size
        find_usernames = usernames_group - users.map(&:username)

        find_usernames.each do |u|
          user = User.where(username: u).first_or_create
          user.update_info!
          users << user if user.insta_id.present?
        end
      end

      users.uniq!

      users.each do |user|
        user.recent_media(total_limit: 50, ignore_added: true, created_from: 5.days.ago) if user.media.where('likes_amount is not null and comments_amount is not null').size < 20 && !user.private?

        media = user.media.order(created_time: :desc).where('created_time < ?', 1.day.ago)
        # media.where('likes_amount is not null or comments_amount is not null').limit(100).each{ |m| m.update_info! }

        likes_amount = media.where('likes_amount is not null').limit(20)
        comments_amount = media.where('comments_amount is not null').limit(20)

        avg_likes = likes_amount.pluck(:likes_amount).sum / likes_amount.size.to_f
        avg_comments = comments_amount.pluck(:comments_amount).sum / comments_amount.size.to_f

        data << [user.username, avg_likes, avg_comments]

        processed += 1

        p "Progress: #{(processed.to_f / usernames.size * 100).to_i}% (#{processed}/#{usernames.size})"
      end
    end

    csv_string = CSV.generate do |csv|
      csv << ['Username', 'AVG Likes', 'AVG Comments']
      data.each do |row|
        begin
          csv << [row[0], row[1].round(2), row[2].round(2)]
        rescue Exception => e
        end
      end
    end

    GeneralMailer.avg_likes_comments(csv_string, usernames).deliver
  end

end