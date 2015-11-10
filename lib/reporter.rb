class Reporter

  def self.media_report *args
    options = args.extract_options!
    ends = options[:ends] || 1.day.ago.end_of_day
    starts = options[:starts] || 6.days.ago(ends).beginning_of_day

    Rails.logger.info "#{"[Media Report]".cyan} Started with #{Tag.exportable.size.to_s.red} tags"

    csv_files = []
    Tag.exportable.each do |tag|
      csv_string = CSV.generate do |csv|
        csv << ['Insta ID', 'Username', 'Full Name', 'Website', 'Bio', 'Follows', 'Followed By', 'Media Amount', 'Added to Instaspy', 'Media URL', 'Media likes', 'Media comments']

        start_time = Time.now
        # catching all users, which did post media with specified tag
        media_users_ids = []
        MediaTag.where(tag_id: tag.id).pluck(:media_id).uniq.in_groups_of(10_000, false) do |group|
          media_users_ids += Media.where(id: group).where("created_time > ?", starts).where("created_time <= ?", ends).pluck(:user_id).uniq
        end
        users_ids = User.where(id: media_users_ids).where("website is not null AND website != ''").where("created_at >= ?", starts).where("created_at <= ?", ends).pluck(:id)
        users_size = users_ids.size
        processed = 0

        Rails.logger.debug "#{"[Media Report]".cyan} Total users for tag #{tag.name.red}: #{users_size} / Initial request: #{(Time.now - start_time).to_f.round(2)}s"

        users_ids.in_groups_of(1000, false) do |users_group_ids|
          users = User.where(id: users_group_ids)
          ts = Time.now

          # select latest media item with current tag for each user from group
          media_items = Media.where(user_id: users_group_ids).has_tag(tag.name).order(created_time: :desc).uniq{|m| m.user_id}

          Rails.logger.debug "#{"[Media Report]".cyan} Media Item request took #{(Time.now - ts).to_f.round(2)}s"

          users.each do |user|
            user.update_info!
            next if user.destroyed?

            start_time = Time.now
            retries = 0
            processed += 1
            media = nil

            Rails.logger.debug "#{"[Media Report]".cyan} Processing #{user.username} (#{user.id})"

            while true
              media = media_items.select{|m| m.user_id.to_s == user.id}.first
              # Rails.logger.info "#{"[Media Report]".cyan} Media found #{media_found}"
              if media
                media_items.slice! media_items.index{|m| m.user_id.to_s == user.id}
                # media = Media.find(media_found[0])
              else
                media = Media.where(user_id: user.id).has_tag(tag.name).order(created_time: :desc).first
              end

              # if we don't have media for that user and tag
              break unless media

              if !user.private? && (media.updated_at < 3.days.ago || media.likes_amount.blank? || media.comments_amount.blank? || media.link.blank?)
                # Rails.logger.info "#{"[Media Report]".cyan} Updating media #{media.id} / retries: #{retries}"
                unless media.update_info! && retries < 5
                  # media.destroy
                  retries += 1
                  redo
                end
              end

              # if media was deleted from instagram and database as well
              redo if media.destroyed?
              break if media.present?
            end

            next unless media
            csv << [
              user.insta_id, user.username, user.full_name, user.website, user.bio, user.follows, user.followed_by,
              user.media_amount, user.created_at.to_s(:date), media.link, media.likes_amount,
              media.comments_amount
            ]

            time_end = Time.now
            Rails.logger.debug "#{"[Media Report]".cyan} #{"#{(processed/users_size.to_f*100).to_i}%".red} (#{processed}/#{users_size}) / Processed #{user.username} (#{user.id}) / Time: #{(time_end - start_time).to_f.round(2)}s"
          end
        end
      end
      csv_files << ["#{tag.name}.csv", csv_string]
    end

    stringio = Zip::OutputStream.write_buffer do |zio|
      csv_files.each do |file|
        zio.put_next_entry(file[0])
        zio.write file[1]
      end
    end
    stringio.rewind
    binary_data = stringio.sysread

    ReportMailer.weekly(binary_data, starts, ends).deliver
  end

  def self.same_followees ids
    data = []
    amounts = {}
    ids.each do |id|
      user = User.find(id)
      user.followees.each do |fol|
        if fol.outdated?
          puts "Updating #{fol.username} ..."
          fol.update_info!
        end
        data << [fol.insta_id, fol.username, fol.full_name, fol.bio, fol.website, fol.follows, fol.followed_by, fol.email]
        amounts[fol.insta_id] = 0 if amounts[fol.insta_id].blank?
        amounts[fol.insta_id] += 1
      end
      puts "Processed #{user.username}. Data size: #{data.size}"
    end
    data.uniq!{|el| el[0]}
    data.map!{|row| row << amounts[row[0]]; row}

    csv_string = CSV.generate do |csv|
      csv << ['ID', 'Username', 'Full Name', 'Bio', 'Website', 'Follows', 'Followers', 'Email']

      data.each do |row|
        csv << row
      end
    end

    filepath = "reports/followees-report-#{Time.now.to_i}.csv"
    File.write "public/#{filepath}", csv_string
    Rails.env.production? ? "http://socialrootdata.com/#{filepath}" : "http://localhost:3000/#{filepath}"
  end

  def self.users_export *args
    options = args.extract_options!

    not_found = []
    options[:additional_columns] ||= []
    feedly_data = nil
    amount = 0

    if options[:usernames]
      users = User.where(username: options[:usernames])
      not_found = options[:usernames] - users.pluck(:username)
      amount = options[:usernames].size
    elsif options[:ids]
      users = User.where(id: options[:ids])
      if options[:additional_columns].include? :feedly
        feedly_data_ar = Feedly.where(website: User.where(id: options[:ids]).pluck(:website)).pluck(:website, :subscribers_amount)
        feedly_data = {}
        feedly_data_ar.each do |fd|
          feedly_data[fd[0]] = fd[1]
        end
      end
      amount = options[:ids].size
    elsif options[:insta_ids]
      users = User.where(insta_id: options[:insta_ids])
      amount = options[:insta_ids].size
    end

    return false unless users

    header = ['Instagram ID', 'Username', 'Full name', 'Bio', 'Website', 'Follows', 'Followers', 'Email']
    header += ['Country', 'State', 'City'] if options[:additional_columns].include? :location
    header += ['AVG Likes'] if options[:additional_columns].include? :likes
    header += ['Feedly Subscribers'] if options[:additional_columns].include? :feedly

    process_user = Proc.new do |u, csv|
      row = [u.insta_id, u.username, u.full_name, u.bio, u.website, u.follows, u.followed_by, u.email]
      row += [u.location_country, u.location_state, u.location_city] if options[:additional_columns].include? :location
      row += [u.avg_likes] if options[:additional_columns].include? :likes
      if options[:additional_columns].include? :feedly
        subscribers_amount = feedly_data ? feedly_data[u.website] : u.feedly.subscribers_amount
        row += [subscribers_amount]
      end

      csv << row
    end

    csv_string = CSV.generate do |csv|
      csv << header

      index = 0
      Rails.logger.debug('Started processing users')
      users.each do |user|
        index += 1
        start = Time.now
        process_user.call(user, csv)
        Rails.logger.debug("Processed user #{user.id} #{index}/#{amount}; time: #{(Time.now - start).to_f.round(2)}s")
      end

      not_found.each do |username|
        user = User.get(username)
        next unless user
        process_user.call(user, csv)
      end
    end

    if options[:return_csv]
      csv_string
    else
      filepath = "reports/users-report-#{Time.now.to_i}.csv"
      FileManager.save_file filepath, content: csv_string
      FileManager.file_url filepath
    end
  end

  def self.influencers
    User.where('followed_by > ?', 1_000).where(private: false).where('media_amount > 0').where('avg_likes is null')
    User.where('followed_by > ?', 1_000).where(private: false).where('media_amount > 0').where('avg_likes is not null')

    # update avg likes
    ids = User.connection.execute("
      SELECT id
      FROM users
      WHERE followed_by > 1000 AND avg_likes is null AND private=0 AND media_amount > 0
    ").to_a.map(&:first)

    # update location
    location_ids = User.connection.execute("
      SELECT id
      FROM users
      WHERE followed_by > 1000 AND avg_likes > 15 AND location_updated_at is null AND private=0 AND media_amount > 0
    ").to_a.map(&:first)

    count = User.connection.execute("
      SELECT count(id)
      FROM users
      WHERE followed_by > 1000 AND avg_likes > 15 AND (location_country='united states' OR location_country='us')
    ").to_a.map(&:first)

  end

  def self.media_likes media_urls
    likes_data = {}
    media_urls.each do |media_url|
      likes_data[media_url] = []

      media = Media.get_from_url media_url

      likes = media.update_likes
      likes.data.each do |like|
        user = User.get(like['id'])
        user.update_info!
        likes_data[media_url] << user
      end

    end

    csv_string = CSV.generate do |csv|
      csv << ['Instagram ID', 'Username', 'Full name', 'Bio', 'Website', 'Follows', 'Followers', 'Email', 'Media URL']
      likes_data.each do |media_url, users|
        users.each do |user|
          csv << [user.insta_id, user.username, user.full_name, user.bio, user.website, user.follows, user.followed_by, user.email, media_url]
        end
      end
    end

    filepath = "reports/media-users-likes-#{Time.now}.csv"
    FileManager.save_file(filepath, content: csv_string)
  end

  def self.invalidate_batches
    Sidekiq::BatchSet.new.each do |status|
      Sidekiq::Batch.new(status.bid).invalidate_all rescue nil
      Sidekiq::Batch.new(status.bid).status.delete rescue nil
    end
    Report.where(status: 'in_process').each do |report|
      report.batches.each do |name, bid|
        Sidekiq::Batch.new(bid).invalidate_all rescue nil
        Sidekiq::Batch.new(bid).status.delete rescue nil
      end
    end
    ReportProcessNewWorker.spawn
    ReportProcessProgressWorker.spawn
  end

end
