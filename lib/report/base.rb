class Report::Base

  def initialize report
    @report = report
    @progress = 0
  end

  def reports_new
    self.process_users_input

    @report.status = :in_process
    @report.started_at = Time.now
    @report.save

    ReportProcessProgressWorker.perform_async @report.id
  end

  protected

  def after_finish
    ReportProcessNewWorker.spawn
  end

  def process_users_input
    processed_input = @report.original_csv.map(&:first)

    insta_ids = processed_input.select{|r| r.numeric?}
    usernames = processed_input - insta_ids

    processed_data = []

    if insta_ids.size > 0
      found_insta_ids = User.where(insta_id: insta_ids).pluck(:insta_id, :id)
      (insta_ids - found_insta_ids.map(&:first)).each do |insta_id|
        user = User.get(insta_id)
        found_insta_ids << [user.insta_id, user.id] if user && user.valid?
      end
      processed_data.concat found_insta_ids
    end

    if usernames.size > 0
      found_usernames = User.where(username: usernames).pluck(:username, :id)
      (usernames - found_usernames.map(&:first)).each do |username|
        u = User.get(username)
        found_usernames << [u.username, u.id] if u && u.valid?
      end
      processed_data.concat found_usernames
    end

    csv_string = CSV.generate do |csv|
      processed_data.each do |row|
        csv << row
      end
    end

    filepath = "reports/reports_data/report-#{@report.id}-processed-input.csv"
    FileManager.save_file filepath, content: csv_string
    @report.processed_input = filepath
  end

  def process_user_info ids=nil
    ids ||= @report.processed_ids

    unless @report.steps.include?('user_info')
      users = User.where(id: ids).outdated(1.day).pluck(:id, :grabbed_at)
      not_updated = users.select{|r| r[1].blank? || r[1] < 36.hours.ago}.map(&:first)

      if not_updated.size == 0
        @report.steps.push 'user_info'
      else
        not_updated.map { |uid| UserWorker.perform_async uid, force: true }
        @progress += (ids.size - not_updated.size) / ids.size.to_f / @parts_amount
      end
    end
  end

  def process_likes processed_ids=nil
    processed_ids ||= @report.processed_ids

    # if we need avg likes data and it is not yet grabbed
    if @report.output_data.include?('likes') && !@report.steps.include?('likes')
      ids = self.get_cached('get_likes', processed_ids)
      get_likes = []
      ids.in_groups_of(5_000, false) do |ids|
        users = User.where(id: ids).without_likes.with_media.not_private.pluck(:id)
        users.each { |uid| UserAvgDataWorker.perform_async uid }
        get_likes.concat users
      end
      if get_likes.size == 0
        self.delete_cached('get_likes')
        @report.steps.push 'likes'
      else
        self.save_cached('get_likes', get_likes)
        @progress += (processed_ids.size - get_likes.size) / processed_ids.size.to_f / @parts_amount
      end
    end
  end

  def process_comments processed_ids=nil
    processed_ids ||= @report.processed_ids

    # if we need avg likes data and it is not yet grabbed
    if @report.output_data.include?('comments') && !@report.steps.include?('comments')
      ids = self.get_cached('get_comments', processed_ids)
      get_comments = []
      ids.in_groups_of(5_000, false) do |ids|
        users = User.where(id: ids).without_comments.with_media.not_private.pluck(:id)
        users.each { |uid| UserAvgDataWorker.perform_async uid }
        get_comments.concat users
      end
      if get_comments.size == 0
        self.delete_cached('get_comments')
        @report.steps.push 'comments'
      else
        self.save_cached('get_comments', get_comments)
        @progress += (processed_ids.size - get_comments.size) / processed_ids.size.to_f / @parts_amount
      end
    end
  end

  def process_location processed_ids=nil
    processed_ids ||= @report.processed_ids

    # if we need location data and it is not yet grabbed
    if @report.output_data.include?('location') && !@report.steps.include?('location')
      ids = self.get_cached('get_location', processed_ids)
      get_location = []
      ids.in_groups_of(5_000, false) do |g|
        users = User.where(id: g).without_location.with_media.not_private.pluck(:id)
        users.each { |uid| UserLocationWorker.perform_async(uid) }
        get_location.concat users
      end
      if get_location.size == 0
        self.delete_cached('get_location')
        @report.steps.push 'location'
      else
        self.save_cached('get_location', get_location)
        @progress += (processed_ids.size - get_location.size) / processed_ids.size.to_f / @parts_amount
      end
    end
  end

  def process_feedly ids=nil
    ids ||= @report.processed_ids

    # if we need feedly subscribers amount and it is not yet grabbed
    if @report.output_data.include?('feedly') && !@report.steps.include?('feedly')
      with_website = []
      feedly_exists = []
      ids.in_groups_of(5_000, false) do |ids|
        for_process = User.where(id: ids).with_url.pluck(:id)
        with_website.concat for_process
        feedly_exists.concat Feedly.where(user_id: for_process).pluck(:user_id)
      end

      no_feedly = with_website - feedly_exists

      if no_feedly.size == 0
        @report.steps.push 'feedly'
      else
        no_feedly.each { |uid| UserFeedlyWorker.perform_async uid }
        @progress += feedly_exists.size / with_website.size.to_f / @parts_amount
      end
    end
  end

  def get_cached name, default=nil
    cached = nil

    if @report.data[name]
      begin
        cached = FileManager.read_file(@report.data[name]).split(',')
      rescue => e
      end
    end

    cached || default
  end

  def save_cached name, data
    filepath = "reports/reports_data/report-#{@report.id}-#{name.gsub(/_/, '-')}"
    FileManager.save_file filepath, content: data.join(',')
    @report.data[name] = filepath
  end

  def delete_cached name
    filepath = "reports/reports_data/report-#{@report.id}-#{name.gsub(/_/, '-')}"
    begin
      FileManager.delete_file filepath if @report.data[name]
    rescue => e
    end
    @report.data.delete(name)
  end

  def grab_followers ids=nil
    ids ||= @report.processed_ids

    if @report.steps.include?('user_info') && !@report.steps.include?('followers')
      users = User.where(id: ids).not_private.where("followers_updated_at is null OR followers_updated_at < ?", 10.days.ago).where('followed_by > 0').map{|u| [u.id, u.followed_by, u.followers_size, u]}
      for_update = users.select{ |r| r[2]/r[1].to_f < 0.95 || r[2]/r[1].to_f > 1.2 }

      if for_update.size == 0
        @report.steps.push 'followers'
        @report.save!
      else
        for_update.each do |row|
          UserFollowersWorker.perform_async row[0], ignore_exists: true, batch: true
        end
        @progress += (ids.size - for_update.size) / ids.size.to_f / @parts_amount
      end
    end
  end

  def update_followers ids=nil
    ids ||= @report.processed_ids

    if @report.steps.include?('followers')

      if @report.data['followers_file'].blank?
        # ids of ALL followers of provided users
        followers_ids = Follower.where(user_id: ids)
        followers_ids = followers_ids.where("followed_at >= ?", @report.date_from) if @report.date_from
        followers_ids = followers_ids.where("followed_at <= ?", @report.date_to) if @report.date_to
        followers_ids = followers_ids.pluck(:follower_id).uniq

        filepath = "reports/reports_data/report-#{@report.id}-followers-ids"
        FileManager.save_file filepath, content: followers_ids.join(',')
        @report.data['followers_file'] = filepath

        # @report.amounts[:followers] = followers_ids.size
        @report.save
      else
        followers_ids = FileManager.read_file(@report.data['followers_file']).split(',')
      end

      @followers_ids = followers_ids

      # update followers info, so in report we will have actual media amount, followers and etc. data
      unless @report.steps.include?('followers_info')

        followers_to_update = self.get_cached('followers_to_update', followers_ids)

        not_updated = []
        followers_to_update.in_groups_of(100_000, false) do |followers_ids|
          # grab all users without data and data outdated for 7 days
          users = User.where(id: followers_ids).outdated(14.days).pluck(:id, :grabbed_at)
          # select users only without data and outdated for 8 days, to avoid adding new users on each iteration
          list = users.select{|r| r[1].blank? || r[1] < 17.days.ago}.map(&:first)

          # in slim report we need only users with emails and over 1k followers. do not update follower if we grab data
          # for him and there is no email in bio
          if @report.output_data.include?('slim')
            users_exclude = User.where(id: list).where('(grabbed_at is not null AND email is null) OR (grabbed_at is not null AND grabbed_at < ? AND followed_by is not null AND followed_by < 900)', 2.months.ago).pluck(:id)
            list -= users_exclude
          end

          if list.size > 0
            not_updated.concat list
          end
        end

        if not_updated.size == 0
          self.delete_cached('followers_to_update')
          @report.steps.push 'followers_info'
        else
          # send to update only first 100k users to not overload query
          not_updated[0...100_000].each do |uid|
            UserWorker.perform_async uid
          end
          self.save_cached('followers_to_update', not_updated)
          @progress += (followers_ids.size - not_updated.size) / followers_ids.size.to_f / @parts_amount
        end
        @report.save
      end
    end
  end

  def grab_followees ids=nil
    ids = @report.processed_ids

    if @report.steps.include?('user_info') && !@report.steps.include?('followees')
      users = User.where(id: ids).not_private.where("followees_updated_at is null OR followees_updated_at < ?", 3.days.ago).where('follows > 0').map{ |u| [u.id, u.follows, u.followees_size] }
      for_update = users.select{|r| r[2]/r[1].to_f < 0.95 || r[2]/r[1].to_f > 1.2 }

      if for_update.size == 0
        @report.steps << 'followees'
      else
        for_update.each { |row| UserFolloweesWorker.perform_async(row[0], ignore_exists: true) }
        @progress += (ids.size - for_update.size) / ids.size.to_f/ @parts_amount
      end
    end
  end

  def update_followees ids=nil
    ids ||= @report.processed_ids

    if @report.steps.include?('followees')

      if @report.data['followees_file'].blank?
        # ids of ALL followees of provided users
        followees_ids = Follower.where(follower_id: ids)
        followees_ids = followees_ids.where("followed_at >= ?", @report.date_from) if @report.date_from.present?
        followees_ids = followees_ids.where("followed_at <= ?", @report.date_to) if @report.date_to.present?
        followees_ids = followees_ids.pluck(:user_id).uniq

        filepath = "reports/reports_data/report-#{@report.id}-followees-ids"
        FileManager.save_file filepath, content: followees_ids.join(',')
        @report.data['followees_file'] = filepath

        # @report.amounts[:followees] = followees_ids.size
        @report.save
      else
        followees_ids = FileManager.read_file(@report.data['followees_file']).split(',')
      end

      @followees_ids = followees_ids

      # update followees info, so in report we will have actual media amount, followees and etc. data
      unless @report.steps.include?('followees_info')
        not_updated = []
        followees_ids.in_groups_of(10_000, false) do |ids|
          users = User.where(id: ids).outdated(7.days).pluck(:id, :grabbed_at)
          not_updated.concat users.select{|r| r[1].blank? || r[1] < 8.days.ago}.map(&:first)
        end
        if not_updated.size == 0
          @report.steps << 'followees_info'
        else
          not_updated.each { |uid| UserWorker.perform_async uid }
          @progress += (followees_ids.size - not_updated.size) / followees_ids.size.to_f / @parts_amount
        end
      end
    end
  end

end
