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
          user.update_info! force: true
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
          user.recent_media(total_limit: 50, ignore_exists: true, created_from: 5.days.ago)
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
        rescue => e
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

    ReportMailer.weekly(csv_files, starts, ends).deliver
  end

  def self.tag_authors tag, timeframe=1.year.ago
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
          user = User.get(username).update_info! force: true
          users << user if user
        end
      end

      users.each do |user|
        p "Start #{user.username}"
        user.update_info! if user.outdated?
        user.recent_media ignore_exists: true, total_limit: media_amount if user.media.size < media_amount
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
      csv << ['Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followed By', 'Media Amount', 'Email', 'Added to Instaspy', 'Media URL', 'Media likes', 'Media comments', 'Media date posted']

      media_list.find_each do |media|
        user = media.user
        user.update_info! if user.outdated?
        # media.update_location! if media.location_present? && media.location_lat.present? && media.location.blank?
        csv << [
          user.username, user.full_name, user.website, user.bio, user.follows, user.followed_by, user.media_amount,
          user.email, user.created_at.strftime('%m/%d/%Y'), media.link, media.likes_amount, media.comments_amount,
          media.created_time.strftime('%m/%d/%Y %H:%M:%S')
        ]
      end

    end

    GeneralMailer.by_location(csv_string).deliver
  end

  def self.user_locations tags_names, *args
    tags_names = [tags_names] if tags_names.class.name == 'String'

    options = args.extract_options!

    options[:followers_min] ||= 500
    options[:likes_min] ||= 50
    start_time = options[:start_time] || 90.days
    at_least = options[:at_least] == false ? false : 500

    data = {}

    tags_names.each do |tag_name|
      tag = Tag.get(tag_name)

      p "Process tag #{tag_name}"

      results = []

      # receive media
      if Time.now - tag.media.order(:created_time).last.created_time > 2.days || (start_time != :all && Time.now - tag.media.order(:created_time).first.created_time < start_time)
        if start_time == :all
          tag.recent_media
        else
          tag.recent_media created_from: start_time.ago
        end
      end

      if at_least && tag.media.size < at_least
        tag.recent_media media_atleast: at_least
      end

      if tag.media.size == 0
        data[tag_name] = {users: [], results: []}
        p "No media for tag #{tag_name}"
        next
      end

        results << ['Total media', tag.media.size]
      p results.map{|el| el.join(' : ')}.last

      # dirty list of users how posted media with specified tag
      if start_time == :all
        users_ids = tag.media
      else
        users_ids = tag.media.where('created_time >= ?', start_time.ago)
      end
      users = User.where(id: users_ids.pluck(:user_id).uniq).to_a

      results << ['Total users', users.size]
      p results.map{|el| el.join(' : ')}.last

      # update users from list
      users.each do |user|
        user.update_info! if user.outdated?
      end

      # leave in list users only with 1000 subscribers
      users.select! { |user| user.followed_by.present? && user.followed_by >= options[:followers_min] }

      results << ["Over #{options[:followers_min]} followers", users.size]
      p results.map{|el| el.join(' : ')}.last

      # update user's avg likes and comments
      users.each do |user|
        user.update_avg_data if user.avg_likes_updated_at.blank? || user.avg_likes_updated_at < 1.month.ago
      end

      # leave in list users only with avg likes amount over or eq to 50
      users.select! { |user| user.avg_likes && user.avg_likes >= options[:likes_min] }

      results << ["Over #{options[:likes_min]} avg likes", users.size]
      p results.map{|el| el.join(' : ')}.last

      # update user's location
      users.each do |user|
        user.popular_location
      end

      users.select! { |user| user.location_country.blank? || user.location_country.downcase.in?(['us', 'united states'])}

      results << ['In USA or location is N/A', users.size]
      p results.map{|el| el.join(' : ')}.last

      # get user's bio, email and website
      users.each do |user|
        user.update_info! if user.outdated?
      end

      results << ['Final result', users.size]

      p results.map{|el| el.join(' : ')}.join(' / ')

      data[tag_name] = {users: users, results: results}
    end

    GeneralMailer.user_locations(data).deliver
  end

  def self.group_csv
    files = Dir.glob('public/reports/users-from-300k/*')
    data = []
    files.each do |file|
      csv = CSV.read file
      csv.shift
      data.concat csv
    end
    data.uniq!{|el| el[0]}
    data.sort!{|a,b| a[0] <=> b[0]}
    csv_string = CSV.generate do |csv|
      data.each do |row|
        csv << row
      end
    end
    File.write 'public/reports/users-from-300k/300k-report.csv', csv_string
  end

  def self.same_followees
    data = []
    amounts = {}
    unames.each do |username|
      User.get(username).followees.each do |fol|
        if fol.grabbed_at.blank? || fol.grabbed_at < 7.days.ago || fol.bio.nil? || fol.website.nil? || fol.follows.blank? || fol.followed_by.blank?
          puts "Updating #{fol.username} ..."
          fol.update_info!
        end
          data << [fol.username, fol.full_name, fol.bio, fol.website, fol.follows, fol.followed_by, fol.email]
        amounts[fol.username] = 0 if amounts[fol.username].blank?
        amounts[fol.username] += 1
      end
      puts "Processed #{username}. Data size: #{data.size}"
    end
    data.uniq!{|el| el[0]}
    data.map!{|row| row << amounts[row[0]]; row}

    data
  end

  # def b
  #   files = []
  #   a.each do |username|
  #     user = User.get(username)
  #
  #     puts "Started #{username.green} - #{user.followers.size} followers"
  #
  #     size =  user.followers.size
  #     processed = 0
  #       user.followers.find_each(batch_size: 5000) do |follower|
  #         processed+=1
  #         if follower.outdated?
  #           puts "Updating info for #{follower.username}"
  #           follower.delay.update_info!
  #         end
  #         puts "#{processed}/#{size}"
  #     end
  #   end
  # end
  #
  # def c
  #   csv_string = CSV.generate do |csv|
  #     csv << ['Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followed By', 'Media Amount', 'Email', 'Country', 'State', 'City']
  #     users.each do |username|
  #       user = User.get(username)
  #       csv << [user.username, user.full_name, user.website, user.bio, user.follows, user.followed_by, user.media_amount, user.email, user.location_country, user.location_state, user.location_city]
  #     end
  #   end
  #   File.write '../../shared/ig-get-locations-march11-results.csv', csv_string
  # end

  def self.latest_30_media usernames, amount=30
    unames = []
    csv_str = CSV.generate do |csv|
      csv << ['Username', 'Likes', 'Comments', 'Date', 'Link', "Tags"]

      usernames.each do |username|
        user = User.add_by_username(username)
        unames << user.username

        user.media.order(created_time: :desc).limit(amount).each do |m|
          m.update_info!
          csv << [user.username, m.likes_amount, m.comments_amount, m.created_time.strftime('%m/%d/%Y'), m.link, m.tags.map(&:name).join(', ')]
        end
      end
    end

    File.write "../../shared/users-latest-#{amount}-media-#{Time.now.to_i}.csv", csv_str
  end

end