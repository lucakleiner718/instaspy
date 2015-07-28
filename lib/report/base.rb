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

  def process_user_info
    unless @report.steps.include?('user_info')
      ids = @report.processed_ids
      users = User.where(id: ids).outdated(1.day).pluck(:id, :grabbed_at)
      not_updated = users.select{|r| r[1].blank? || r[1] < 36.hours.ago}.map(&:first)

      if not_updated.size == 0
        @report.steps.push 'user_info'
      else
        not_updated.map { |uid| UserWorker.perform_async uid, true }
        @progress += (ids.size - not_updated.size) / ids.size.to_f / @parts_amount
      end
    end
  end

  def process_likes ids
    # if we need avg likes data and it is not yet grabbed
    if @report.output_data.include?('likes') && !@report.steps.include?('likes')
      ids = self.get_cached('get_likes', ids)
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
        @progress += (ids.size - get_likes.size) / ids.size.to_f / @parts_amount
      end
    end
  end

  def process_comments ids
    # if we need avg likes data and it is not yet grabbed
    if @report.output_data.include?('comments') && !@report.steps.include?('comments')
      ids = self.get_cached('get_comments', ids)
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
        @progress += (ids.size - get_comments.size) / ids.size.to_f / @parts_amount
      end
    end
  end

  def process_location ids
    # if we need location data and it is not yet grabbed
    if @report.output_data.include?('location') && !@report.steps.include?('location')
      ids = self.get_cached('get_location', ids)
      get_location = []
      ids.in_groups_of(5_000, false) do |ids|
        users = User.where(id: ids).without_location.with_media.not_private.pluck(:id)
        users.each { |uid| UserLocationWorker.perform_async(uid) }
        get_location.concat users
      end
      if get_location.size == 0
        self.delete_cached('get_location')
        @report.steps.push 'location'
      else
        self.save_cached('get_location', get_location)
        @progress += (ids.size - get_location.size) / ids.size.to_f / @parts_amount
      end
    end
  end

  def process_feedly ids
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

end
