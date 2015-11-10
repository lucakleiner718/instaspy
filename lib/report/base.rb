class Report::Base

  BATCH_UPDATE = 20_000

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

  def get_batch batch_name
    batch = nil
    if @report.batches[batch_name.to_s].present?
      batch = Sidekiq::Batch.new(@report.batches[batch_name.to_s]) rescue nil
    end
    if batch
      unless Sidekiq::BatchSet.new.map{|status| status.bid}.include?(batch.bid)
        Sidekiq::Batch.new(batch.bid).invalidate_all rescue nil
        Sidekiq::Batch.new(batch.bid).status.delete rescue nil
        batch = nil
      end
    end
    if batch
      begin
        Sidekiq::Batch::Status.new(batch.bid)
      rescue => e
        Sidekiq::Batch.new(batch.bid).invalidate_all rescue nil
        Sidekiq::Batch.new(batch.bid).status.delete rescue nil
        batch = nil
      end
    end
    if batch
      pending = batch.status.pending
      if Sidekiq::Queue.all.select{|q| q.size > pending}.size == 0
        Sidekiq::Batch.new(batch.bid).invalidate_all rescue nil
        Sidekiq::Batch.new(batch.bid).status.delete rescue nil
        batch = nil
      end
    end
    unless batch
      batch = Sidekiq::Batch.new
      batch.on(:success, 'Report::Callback', class_name: self.class.name, report_id: @report.id)
      batch.on(:complete, 'Report::Callback', class_name: self.class.name, report_id: @report.id)
      batch.description = "Report #{@report.id} batch for #{batch_name}"
      @report.batches[batch_name.to_s] = batch.bid
      @report.save if @report.changed?
    end
    if batch && batch.jids.size > 0 && batch.status.pending < 1
      batch.invalidate_all rescue nil
      batch.status.delete rescue nil
      batch = nil
    end
    batch
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
      batch = get_batch(:user_info)
      if batch && batch.jids.size > 0
        @progress += (batch.status.total - batch.status.pending) / batch.status.total.to_f / @parts_amount
      else
        not_updated = User.where(id: ids).outdated(1.day.ago(@report.created_at)).pluck(:id)
        if not_updated.size == 0
          @report.steps.push 'user_info'
          @report.save
        else
          batch.jobs do
            not_updated.map { |uid| UserUpdateWorker.perform_async uid, force: true }
          end
          @progress += (ids.size - not_updated.size) / ids.size.to_f / @parts_amount
        end
      end
    end
  end

  def process_avg_data processed_ids=nil
    processed_ids ||= @report.processed_ids

    # if we need avg likes data and it is not yet grabbed
    if (@report.output_data.include?('likes') && !@report.steps.include?('likes')) || (@report.output_data.include?('comments') && !@report.steps.include?('comments'))
      batch = get_batch(:avg_data)
      if batch && batch.jids.size > 0
        @progress += (batch.status.total - batch.status.pending) / batch.status.total.to_f / @parts_amount
      else
        ids = self.get_cached('get_avg_data', processed_ids)
        get_avg_data = []
        ids.in_groups_of(5_000, false) do |ids|
          get_avg_data.concat User.where(id: ids).without_avg_data.with_media.not_private.pluck(:id)
        end
        if get_avg_data.size == 0
          self.delete_cached('get_avg_data')
          @report.steps.push 'likes' if @report.output_data.include?('likes')
          @report.steps.push 'comments' if @report.output_data.include?('comments')
          @report.save
        else
          batch.jobs do
            get_avg_data.each do |uid|
              UserAvgDataWorker.perform_async uid
            end
          end
          self.save_cached('get_avg_data', get_avg_data)
          @progress += (processed_ids.size - get_avg_data.size) / processed_ids.size.to_f / @parts_amount
        end
      end
    end
  end

  def process_location processed_ids=nil
    processed_ids ||= @report.processed_ids

    # if we need location data and it is not yet grabbed
    if @report.output_data.include?('location') && !@report.steps.include?('location')
      batch = get_batch(:location)
      if batch && batch.jids.size > 0
        @progress += (batch.status.total - batch.status.pending) / batch.status.total.to_f / @parts_amount
      else
        ids = self.get_cached('get_location', processed_ids)
        get_location = []
        ids.in_groups_of(20_000, false) do |g|
          users = User.where(id: g).without_location.with_media.not_private.pluck(:id)
          get_location.concat users
        end
        if get_location.size == 0
          self.delete_cached('get_location')
          @report.steps.push 'location'
        else
          batch.jobs do
            get_location.each do |uid|
              UserLocationWorker.perform_async uid
            end
          end
          self.save_cached('get_location', get_location)
          @progress += (processed_ids.size - get_location.size) / processed_ids.size.to_f / @parts_amount
        end
      end
    end
  end

  def process_feedly ids=nil
    ids ||= @report.processed_ids

    # if we need feedly subscribers amount and it is not yet grabbed
    if @report.output_data.include?('feedly') && !@report.steps.include?('feedly')
      batch = get_batch(:feedly)
      if batch && batch.jids.size > 0
        @progress += (batch.status.total - batch.status.pending) / batch.status.total.to_f / @parts_amount
      else
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
          @report.save
        else
          get_batch(:feedly).jobs do
            no_feedly.each do |uid|
              UserFeedlyWorker.perform_async uid
            end
          end
          @progress += feedly_exists.size / with_website.size.to_f / @parts_amount
        end
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
      batch = get_batch(:followers_collect)
      if batch && batch.jids.size > 0
        @progress += (batch.status.total - batch.status.pending) / batch.status.total.to_f / @parts_amount
      else
        for_update = User.where(id: ids).not_private.where('followed_by > 0').map{|u| [u.id, u.followed_by, u.followers_size, u]}.select{ |r| r[2]/r[1].to_f < 0.95 || (r[2]/r[1].to_f > 1.2 && r[1] < 50_000) }

        if for_update.size == 0
          @report.steps.push 'followers'
          @report.save
          User.where(id: ids).not_private.where("followers_updated_at is null OR followers_updated_at < ?", 10.days.ago).where('followed_by > 0').update_all(followers_updated_at: Time.now)
        else
          get_batch(:followers_collect).jobs do
            for_update.each do |r|
              UserFollowersCollectWorker.perform_async r[0], ignore_exists: true
            end
          end
          @progress += (ids.size - for_update.size) / ids.size.to_f / @parts_amount
        end
      end
    end
  end

  def update_followers ids=nil
    ids ||= @report.processed_ids

    if @report.steps.include?('followers')

      if @report.data['followers_file'].present?
        followers_ids = FileManager.read_file(@report.data['followers_file']).split(',')
      else
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
      end

      @followers_ids = followers_ids

      # update followers info, so in report we will have actual media amount, followers and etc. data
      unless @report.steps.include?('followers_info')
        batch = get_batch(:followers_update)
        if batch && batch.jids.size > 0
          @progress += (batch.status.total - batch.status.pending) / batch.status.total.to_f / @parts_amount
        else
          followers_to_update = self.get_cached('followers_to_update', followers_ids)

          not_updated = []
          followers_to_update.in_groups_of(50_000, false) do |part_ids|
            # grab all users without data and data outdated for 14 days
            list = User.where(id: part_ids).outdated(30.days.ago(@report.created_at)).pluck(:id)

            # in slim report we need only users with emails and over 1k followers. do not update follower if we grab data
            # for him and there is no email in bio
            if @report.output_data.include?('slim')
              users_exclude = User.where(id: list).where('(grabbed_at IS NOT NULL AND email IS NULL) OR (grabbed_at IS NOT NULL AND grabbed_at < ? AND followed_by IS NOT NULL AND followed_by < ?)', 2.months.ago, 900).pluck(:id)
              list -= users_exclude
            end

            if @report.output_data.include?('slim_followers')
              users_exclude = User.where(id: list).where('grabbed_at IS NOT NULL AND grabbed_at < ? AND followed_by IS NOT NULL AND followed_by < ?', 3.months.ago, 900).pluck(:id)
              list -= users_exclude
            end

            if list.size > 0
              not_updated.concat list
            end
          end

          if not_updated.size == 0
            self.delete_cached('followers_to_update')
            @report.steps.push 'followers_info'
            @report.save
          else
            get_batch(:followers_update).jobs do
              not_updated.each do |uid|
                UserUpdateWorker.perform_async uid
              end
            end
            self.save_cached('followers_to_update', not_updated)
            @progress += (followers_ids.size - not_updated.size) / followers_ids.size.to_f / @parts_amount
          end
          @report.save
        end
      end
    end
  end

  def grab_followees ids=nil
    ids ||= @report.processed_ids

    if @report.steps.include?('user_info') && !@report.steps.include?('followees')
      batch = get_batch(:followees_collect)
      if batch && batch.jids.size > 0
        @progress += (batch.status.total - batch.status.pending) / batch.status.total.to_f / @parts_amount
      else
        for_update = User.where(id: ids).not_private.where('follows > 0').map{|u| [u.id, u.follows, u.followees_size, u]}.select{ |r| r[2]/r[1].to_f < 0.95 || (r[2]/r[1].to_f > 1.2 && r[1] < 50_000) }

        if for_update.size == 0
          @report.steps.push 'followees'
          @report.save
        else
          get_batch(:followees_collect).jobs do
            for_update.each do |r|
              UserFolloweesCollectWorker.perform_async r[0], ignore_exists: true
            end
          end
          @progress += (ids.size - for_update.size) / ids.size.to_f/ @parts_amount
        end
      end
    end
  end

  def update_followees ids=nil
    ids ||= @report.processed_ids

    if @report.steps.include?('followees')

      if @report.data['followees_file'].present?
        followees_ids = FileManager.read_file(@report.data['followees_file']).split(',')
      else
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
      end

      @followees_ids = followees_ids

      # update followees info, so in report we will have actual media amount, followees and etc. data
      unless @report.steps.include?('followees_info')
        batch = get_batch(:followees_update)
        if batch && batch.jids.size > 0
          @progress += (batch.status.total - batch.status.pending) / batch.status.total.to_f / @parts_amount
        else
          not_updated = []
          followees_ids.in_groups_of(20_000, false) do |ids|
            not_updated.concat User.where(id: ids).outdated(7.days.ago(@report.created_at)).pluck(:id)
          end
          if not_updated.size == 0
            @report.steps.push 'followees_info'
            @report.save
          else
            get_batch(:followees_update).jobs do
              not_updated.each do |uid|
                UserUpdateWorker.perform_async uid
              end
            end
            @progress += (followees_ids.size - not_updated.size) / followees_ids.size.to_f / @parts_amount
          end
        end
      end
    end
  end

end
