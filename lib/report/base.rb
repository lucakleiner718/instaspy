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

    # convert all insta_ids to integer
    insta_ids.map!(&:to_i)

    processed_data = []

    if insta_ids.size > 0
      found_insta_ids = User.in(insta_id: insta_ids).pluck(:insta_id, :id)
      (insta_ids - found_insta_ids.map(&:first)).each do |insta_id|
        u = User.get(insta_id: insta_id)
        found_insta_ids << [u.insta_id, u.id] if u && u.valid?
      end
      processed_data.concat found_insta_ids
    end

    if usernames.size > 0
      found_usernames = User.in(username: usernames).pluck(:username, :id)
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
      users = User.in(id: ids).outdated(1.day).pluck(:id, :grabbed_at)
      not_updated = users.select{|r| r[1].blank? || r[1] < 36.hours.ago}.map(&:first)

      if not_updated.size == 0
        @report.push steps: 'user_info'
      else
        not_updated.map { |uid| UserWorker.perform_async uid, true }
        @progress += (ids.size - not_updated.size) / ids.size.to_f / @parts_amount
      end
    end
  end

  def process_likes ids
    # if we need avg likes data and it is not yet grabbed
    if @report.output_data.include?('likes') && !@report.steps.include?('likes')
      get_likes = []
      ids.in_groups_of(5_000, false) do |ids|
        get_likes.concat User.in(id: ids).without_likes.with_media.not_private.pluck(:id)
      end
      if get_likes.size == 0
        @report.push steps: 'likes'
      else
        get_likes.each { |uid| UserAvgLikesWorker.perform_async uid }
        @progress += (ids.size - get_likes.size) / ids.size.to_f / @parts_amount
      end
    end
  end

  def process_location ids
    # if we need location data and it is not yet grabbed
    if @report.output_data.include?('location') && !@report.steps.include?('location')
      get_location = []
      ids.in_groups_of(5_000, false) do |ids|
        get_location.concat User.in(id: ids).without_location.with_media.not_private.pluck(:id)
      end
      if get_location.size == 0
        @report.push steps: 'location'
      else
        get_location.each { |uid| UserLocationWorker.perform_async(uid) }
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
        for_process = User.in(id: ids).with_url.pluck(:id)
        with_website.concat for_process
        feedly_exists.concat Feedly.in(user_id: for_process).pluck(:user_id)
      end

      no_feedly = with_website - feedly_exists

      if no_feedly.size == 0
        @report.push steps: 'feedly'
      else
        no_feedly.each { |uid| UserFeedlyWorker.perform_async uid }
        @progress += feedly_exists.size / with_website.size.to_f / @parts_amount
      end
    end
  end

end