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

        # freq = media.limit(20)
        # media_freq = 0
        # if freq.size > 0
        #   media_freq = freq.size.to_f / (Time.now.to_i - freq.last.created_time.to_i) * 60 * 60 * 24
        # end

        data << { name: user.full_name, username: user.username, likes: avg_likes, comments: avg_comments, media: media.first }

        processed += 1

        p "Progress: #{(processed.to_f / usernames.size * 100).to_i}% (#{processed}/#{usernames.size})"
      end
    end

    csv_string = CSV.generate do |csv|
      csv << ['Name', 'Username', 'AVG Likes', 'AVG Comments', 'Last Media URL' ]
      data.each do |row|
        begin
          csv << [ row[:name], row[:username], row[:likes].round(2), row[:comments].round(2), row[:media].link ]
        rescue Exception => e
        end
      end
    end

    not_processed = usernames - data.map{|el| el[:username]}

    p "Not processed: #{not_processed}"

    GeneralMailer.avg_likes_comments(csv_string, usernames, not_processed).deliver
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

  def self.delay_location_report usernames, split=500
    usernames.in_groups_of(split, false).each do |usernames_group|
      Reporter.delay(queue: :critical).location_report usernames_group, false
    end
  end

  def self.location_report usernames, send_email=true
    # ActiveRecord::Base.logger.level = 1
    data = []
    media_amount = 50

    usernames.in_groups_of(100, false) do |group|
      users = User.where(username: group).to_a

      if users.size < group.size
        not_exists = group - users.map{|el| el.username}
        not_exists.each do |username|
          user = User.get(username).update_info!
          users << user if user
        end
      end

      users.each do |user|
        p "Start #{user.username}"
        user.update_info! if user.grabbed_at < 7.days.ago
        user.recent_media ignore_added: true, total_limit: media_amount if user.media.size < media_amount
        user.update_media_location
        data << [user.username, user.popular_location]
        p "Added #{user.username} [#{data.size}/#{usernames.size}]"
      end
    end

    not_processed = usernames - data.map{|el| el[0]}
    if not_processed.size > 0
      p "Not processed: #{not_processed.join(', ')}"
    end

    GeneralMailer.location_report(data, not_processed).deliver if send_email
  end

  def self.by_location lat, lng, *args
    options = args.extract_options!
    options[:distance] ||= 100

    media_list = Media.near([lat, lng], options[:distance]/1000, units: :km).includes(:user)
    media_list = media_list.where('created_time >= ?', options[:created_till]) if options[:created_till].present?

    csv_string = CSV.generate do |csv|
      csv << ['Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followed By', 'Media Amount', 'Email', 'Added to Instaspy', 'Media URL', 'Media likes', 'Media comments', 'Location']

      media_list.find_each do |media|
        user = media.user
        user.update_info! if user.grabbed_at.blank? || user.grabbed_at < 7.days.ago || user.bio.blank? || user.website.blank? || user.email.blank?
        media.update_location! if media.location_present? && media.location_lat.present? && media.location.blank?
        csv << [
          user.username, user.full_name, user.website, user.bio, user.follows, user.followed_by, user.media_amount,
          user.email, user.created_at.strftime('%m/%d/%Y'), media.link, media.likes_amount, media.comments_amount,
          media.location
        ]
      end

    end

    GeneralMailer.by_location(csv_string).deliver
  end

  def self.user_locations tag_name
    tag = Tag.get(tag_name)

    start_time = 90.days

    # receive media
    if Time.now - tag.media.order(:created_time).last.created_time > 3.days || Time.now - tag.media.order(:created_time).first.created_time < start_time || tag.media.size < 10
      tag.recent_media created_from: start_time.ago
    end

    # binding.pry

    # dirty list of users how posted media with specified tag
    users_ids = tag.media.where('created_time >= ?', start_time.ago).pluck(:user_id).uniq
    users = User.where(id: users_ids).to_a

    # binding.pry

    # update users from list
    users.each do |user|
      # user.update_info! if user.grabbed_at.blank? || user.grabbed_at < 7.days.ago || user.followed_by.blank?
      user.update_info! if user.grabbed_at.blank? || user.followed_by.blank?
    end

    blank_followed_amount = users.select{ |user| user.followed_by.blank? }

    # leave in list users only with 1000 subscribers
    users.select! { |user| user.followed_by >= 500 }

    # binding.pry

    # update user's avg likes and comments
    users.each do |user|
      user.update_avg_data if user.avg_likes_updated_at.blank? || user.avg_likes_updated_at < 1.month.ago
    end

    # leave in list users only with avg likes amount over or eq to 50
    users.select! { |user| user.avg_likes >= 50 }

    # binding.pry

    # update user's location
    users.each do |user|
      user.popular_location
    end

    users.select! { |user| user.location_country.blank? || user.location_country.in?(['us', 'united states'])}

    # binding.pry

    # get user's bio, email and website
    users.each do |user|
      user.update_info! if user.bio.blank? || user.email.blank? || user.website.blank?
    end

    # binding.pry

    users
  end

end