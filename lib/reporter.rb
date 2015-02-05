class Reporter

  def self.avg_likes_comments usernames

    data = []
    processed = 0

    usernames.in_groups_of(100, false).each do |usernames_group|
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

      p "Users size #{users.size}"

      users.each do |user|
        if user.private? && user.media.where('likes_amount is not null and comments_amount is not null').size < 2
          next
        end

        if user.media.where('likes_amount is not null and comments_amount is not null').size < 20 && !user.private?
          p "Get Users media #{user.id}"
          user.recent_media(total_limit: 50, ignore_added: true, created_from: 5.days.ago)
        end

        media = user.media.order(created_time: :desc).where('created_time < ?', 1.day.ago)
        # media.where('likes_amount is not null or comments_amount is not null').limit(100).each{ |m| m.update_info! }

        likes_amount = media.where('likes_amount is not null').limit(20)
        comments_amount = media.where('comments_amount is not null').limit(20)

        avg_likes = likes_amount.pluck(:likes_amount).sum / likes_amount.size.to_f
        avg_comments = comments_amount.pluck(:comments_amount).sum / comments_amount.size.to_f

        freq = media.limit(20)
        media_freq = 0
        if freq.size > 0
          media_freq = freq.size.to_f / (Time.now.to_i - freq.last.created_time.to_i) * 60 * 60 * 24
        end

        data << { name: user.full_name, username: user.username, likes: avg_likes, comments: avg_comments, freq: media_freq }

        processed += 1

        p "Progress: #{(processed.to_f / usernames.size * 100).to_i}% (#{processed}/#{usernames.size})"
      end
    end

    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'AVG Likes', 'AVG Comments', 'Media per day']
      data.each do |row|
        begin
          csv << [ row[:name], row[:username], row[:likes].round(2), row[:comments].round(2), row[:freq].round(4) ]
        rescue Exception => e
        end
      end
    end

    GeneralMailer.avg_likes_comments(csv_string, usernames).deliver
  end

  def self.media_report *args
    options = args.extract_options!

    ends = options[:ends] || 1.day.ago.end_of_day
    starts = options[:starts] || 6.days.ago(ends).beginning_of_day

    header = ['Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followed By', 'Media Amount', 'Added to Instaspy', 'Media URL', 'Media likes', 'Media comments']
    csv_files = {}
    Tag.exportable.each do |tag|
      csv_string = CSV.generate do |csv|
        csv << header

        # catching all users, which did post media with specified tag
        users_ids = tag.media.where('created_at > ? AND created_at <= ?', starts, ends).pluck(:user_id).uniq

        users_ids.in_groups_of(1000, false).each do |user_ids_group|
          users = User.where(id: user_ids_group).where("website is not null AND website != ''")
                      .where('users.created_at >= ?', starts).where('users.created_at <= ?', ends)
                    # .joins(:media => [:tags]).where('tags.name = ?', Tag.observed.first.name)
                    # .select([:id, :username, :full_name, :website, :bio, :follows, :followed_by, :media_amount, :created_at, :private])

          users.find_each do |user|
            while true
              media = user.media.joins(:tags).where('tags.name = ?', tag.name).order(created_at: :desc).where('created_time < ?', 1.day.ago).first
              media = user.media.joins(:tags).where('tags.name = ?', tag.name).order(created_at: :desc).first if media.blank?
              # if we don't have media for that user and tag
              break unless media
              if !user.private? && (media.updated_at < 3.days.ago || media.likes_amount.blank? || media.comments_amount.blank? || media.link.blank?)
                unless media.update_info!
                  # media.destroy
                  redo
                end
              end
              # if media was deleted from instagram
              redo if media.destroyed?
              break if media.present?
            end

            next unless media
            csv << [
              user.username, user.full_name, user.website, user.bio, user.follows, user.followed_by, user.media_amount,
              user.created_at.strftime('%m/%d/%Y'), media.link, media.likes_amount, media.comments_amount
            ]
          end
        end
      end
      csv_files[tag.name] = csv_string
    end
    csv_files

    ReportMailer.weekly(csv_files, starts, ends).deliver
  end

  def self.tag_authors tag, timeframe
    users = []
    tag.media.where('created_at > ?', timeframe).includes(:user).each do |media|
      users << media.user
    end

    users.uniq!

    GeneralMailer.tag_authors(tag, users).deliver
  end

end