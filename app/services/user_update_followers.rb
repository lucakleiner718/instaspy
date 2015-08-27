class UserUpdateFollowers < ServiceObject

  def perform user_id: nil, user: nil, options: {}
    if !user && user_id
      user = User.find(user_id)
    end

    return false if !user

    # to be sure all user's details are up-to-date
    user.update_info! force: true

    return false if user.insta_id.blank? || user.destroyed? || user.private?

    options.symbolize_keys!

    cursor = options[:start_cursor] ? options[:start_cursor].to_f.round(3).to_i * 1_000 : nil
    finish_cursor = options[:finish_cursor] ?  options[:finish_cursor].to_f.round(3).to_i * 1_000 : nil

    return false if options[:start_cursor] && options[:start_cursor] < 0

    if options[:continue]
      last_follow_time = Follower.where(user_id: user.id).where("followed_at is not null").order(followed_at: :asc).first.try(:followed_at)
      if last_follow_time
        cursor = last_follow_time.to_i * 1_000
      end
    end

    options[:count] ||= 100

    if options[:reload]
      Follower.where(user_id: user.id).destroy_all
    end

    followers_ids = []
    total_exists = 0
    total_added = 0
    skipped = false

    while true
      start = Time.now

      exists = 0
      added = 0
      retries = 0

      begin
        @client = InstaClient.new
        resp = @client.client.user_followed_by user.insta_id, cursor: cursor, count: options[:count]
      rescue Instagram::ServiceUnavailable, Instagram::TooManyRequests, Instagram::BadGateway, Instagram::InternalServerError,
        Instagram::GatewayTimeout, JSON::ParserError, Faraday::ConnectionFailed, Faraday::SSLError, Zlib::BufError,
        Errno::EPIPE, Errno::ETIMEDOUT => e
        logger.debug e.message
        sleep 10*retries
        retries += 1
        retry if retries <= 5
        raise e
      rescue Instagram::BadRequest => e
        logger.debug e.message
        if e.message =~ /you cannot view this resource/
          user.update_info! force: true
          break
        elsif e.message =~ /this user does not exist/
          user.destroy
          return false
        elsif e.message =~ /The access_token provided is invalid/
          @client.login.destroy
          retry
        end
        raise e
      end

      end_ig = Time.now

      exists_users = User.where(insta_id: resp.data.map{|el| el['id']}).to_a
      fols = Follower.where(user_id: user.id, follower_id: exists_users.map(&:id)).to_a

      followers_to_create = []
      followers_for_update = []
      # cursor is kind of timestamp or if request is first
      followed_at = cursor ? Time.at(cursor.to_i/1000) : Time.now.utc

      resp.data.each do |user_data|
        new_record = false

        row_user = exists_users.select{|el| el.insta_id == user_data['id']}.first
        unless row_user
          row_user = User.new insta_id: user_data['id']
          new_record = true
        end

        # some unexpected behavior
        if row_user.insta_id.present? && user_data['id'].present? && row_user.insta_id != user_data['id']
          raise Exception
        end

        row_user.set_data user_data

        # this can return another user or same saved
        row_user = row_user.must_save if row_user.changed?

        followers_ids << row_user.id

        if new_record
          followers_to_create << [user.id, row_user.id, followed_at]
        else
          if options[:reload]
            followers_to_create << [user.id, row_user.id, followed_at]
          else
            fol_exists = fols.select{ |el| el.follower_id == row_user.id }.first

            if fol_exists
              if fol_exists.followed_at.blank? || fol_exists.followed_at > followed_at
                # fol_exists.update_column :followed_at, followed_at
                followers_for_update << fol_exists.id
              end
              exists += 1
            else
              followers_to_create << [user.id, row_user.id, followed_at]
            end
          end
        end
      end

      if followers_for_update.size > 0
        Follower.where(id: followers_for_update).update_all(followed_at: followed_at)
      end

      added += followers_to_create.size

      if followers_to_create.size > 0
        begin
          Follower.connection.execute("INSERT INTO followers (user_id, follower_id, followed_at, created_at) VALUES #{followers_to_create.map{|r| r << Time.now; "(#{r.map{|el| "'#{el}'"}.join(', ')})"}.join(', ')}")
        rescue => e
          logger.debug "Exception when try to multiple insert followers".black.on_white
          followers_to_create.each do |follower|
            fol = Follower.where(user_id: follower[0], follower_id: follower[1]).first_or_initialize
            fol.followed_at = follower[2]
            fol.save! rescue false
          end
        end
      end

      total_exists += exists
      total_added += added

      finish = Time.now
      logger.debug ">> [#{user.username.green}] followers:#{user.followed_by} request: #{(finish-start).to_f.round(2)}s :: IG request: #{(end_ig-start).to_f.round(2)}s / exists: #{exists} (#{total_exists.to_s.light_black}) / added: #{added} (#{total_added.to_s.light_black})"

      if exists > 5
        if options[:skip_exists] && !skipped
          last_follow_time = Follower.where(user_id: user.id).where("followed_at is not null").order(followed_at: :asc).first
          if last_follow_time
            cursor = last_follow_time.followed_at.to_i * 1_000
            skipped = true
            next
          end
        end
      end

      if !options[:ignore_exists] && exists > 5
        user.followers_updated_time!
        break
      end

      cursor = resp.pagination['next_cursor']

      unless cursor
        if !options[:reload] && !skipped && options[:start_cursor].blank? && options[:finish_cursor].blank?
          current_followers = Follower.where(user_id: user.id).pluck(:follower_id)
          unfollowed = current_followers - followers_ids
          if unfollowed.size > 0
            Follower.where(user_id: user.id).where(follower_id: unfollowed).delete_all
          end
        end
        user.delete_duplicated_followers!

        user.followers_updated_time!

        break
      end

      if finish_cursor && cursor.to_i < finish_cursor
        logger.debug "#{"Stopped".red} by finish_cursor point finish_cursor: #{Time.at(finish_cursor/1000)} (#{finish_cursor}) / cursor: #{Time.at(cursor.to_i/1000)} (#{cursor}) / added: #{total_added}"
        break
      end
    end

    user.save! if user.changed?

    true
  end

end