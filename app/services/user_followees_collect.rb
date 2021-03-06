class UserFolloweesCollect < ServiceObject

  def perform user_id: nil, user: nil, options: {}
    if !user && user_id
      user = User.find(user_id)
    end

    return false if !user

    # to be sure all user's details are up-to-date
    user.update_info! force: true

    return false if user.insta_id.blank? || user.destroyed? || user.private?

    options.symbolize_keys!

    cursor = options[:start_cursor]

    options[:count] ||= 100

    if options[:reload]
      Follower.where(follower_id: user.id).destroy_all
    end

    followees_ids = []
    total_exists = 0
    total_added = 0
    skipped = false

    while true
      start = Time.now

      exists = 0
      added = 0

      begin
        ic = InstaClient.new
        resp = ic.client.user_follows user.insta_id, cursor: cursor, count: options[:count]
      rescue Instagram::BadRequest => e
        logger.debug e.message
        if e.message =~ /you cannot view this resource/
          user.update_info! force: true
          break
        elsif e.message =~ /this user does not exist/
          user.destroy
          return false
        end
        raise e
      end

      end_ig = Time.now

      exists_users = User.where(insta_id: resp.data.map{|el| el['id']}).to_a
      fols = Follower.where(follower_id: user.id, user_id: exists_users.map(&:id)).to_a

      to_create = []

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

        followees_ids << row_user.id

        if new_record
          to_create << [user.id, row_user.id]
        else
          if options[:reload]
            to_create << [user.id, row_user.id]
          else
            fol_exists = fols.select{ |el| el.user_id == row_user.id }.first

            if fol_exists
              exists += 1
            else
              to_create << [user.id, row_user.id]
            end
          end
        end
      end

      added += to_create.size

      if to_create.size > 0
        begin
          Follower.connection.execute("INSERT INTO followers (follower_id, user_id, created_at) VALUES #{to_create.map{|r| r << Time.now.utc; "(#{r.map{|el| "'#{el}'"}.join(', ')})"}.join(', ')}")
        rescue => e
          logger.debug "Exception when try to multiple insert followees".black.on_white
          to_create.each do |follower|
            fol = Follower.where(user_id: follower[1], follower_id: follower[0]).first_or_initialize
            fol.save! rescue false
          end
        end
      end

      total_exists += exists
      total_added += added

      finish = Time.now
      logger.debug ">> [#{user.username.green}] followees:#{user.follows} request: #{(finish-start).to_f.round(2)}s :: IG request: #{(end_ig-start).to_f.round(2)}s / exists: #{exists} (#{total_exists.to_s.light_black}) / added: #{added} (#{total_added.to_s.light_black})"

      if !options[:ignore_exists] && exists > 5
        user.followees_updated_time!
        break
      end

      cursor = resp.pagination['next_cursor']

      # when code reached end of list
      unless cursor
        if !options[:reload] && !skipped && options[:start_cursor].blank?
          current_followees = Follower.where(follower_id: user.id).pluck(:user_id)
          unfollowed = current_followees - followees_ids
          if unfollowed.size > 0
            Follower.where(follower_id: user.id).where(user_id: unfollowed).delete_all
          end
        end
        user.delete_duplicated_followees!

        user.followees_updated_time!

        break
      end
    end

    user.save! if user.changed?

    true
  end

end
