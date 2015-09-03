class UsersController < ApplicationController
  def index
    @users = User.page(params[:page]).per(20)

    @followees = {}
    Follower.where(follower_id: @users.map(&:id)).each do |f|
      @followees[f.follower_id] ||= 0
      @followees[f.follower_id] += 1
    end

    @followers = {}
    Follower.where(user_id: @users.map(&:id)).each do |f|
      @followees[f.user_id] ||= 0
      @followees[f.user_id] += 1
    end
  end

  # TODO
  def followers_chart
    @user = User.find_by(username: params[:id])

    data = Follower.connection.execute("
        SELECT * FROM (
            SELECT sum(1) as total, extract(month from followed_at) as month, extract(year from followed_at) as year
            FROM followers
            WHERE user_id=#{@user.id} AND followed_at is not null
            GROUP BY extract(month from followed_at), extract(year from followed_at)
        ) as temp
        ORDER BY year, total
    ")

    data = data.to_a.inject({}) do |obj, el|
      date = DateTime.parse("#{el['year']}/#{el['month']}/1").to_i * 1000
      obj[date] = el['total'].to_i
      obj
    end
    @data = data.sort
  end

  def duplicates
    content = params[:file].read.split(/\r\n|\r|\n/).map(&:to_i)
    output = {}
    content.each do |id|
      output[id] = 0 if output[id].nil?
      output[id] += 1
    end

    output = output.inject([]){|ar, (k,v)| ar << [k,v]; ar}.sort{|a,b| a[0] <=> b[0]}

    csv_string = CSV.generate do |csv|
      output.each do |k, v|
        csv << [k,v]
      end
    end

    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: "processed-file-#{Time.now.to_i}.csv"
  end

  def export

  end

  def export_process
    location = params[:location]
    users = User.all

    if location[:country].present?
      users = users.where('LOWER(location_country) = LOWER(?)', location[:country])
    end

    if location[:state].present?
      users = users.where('LOWER(location_state) ILIKE LOWER(?)', "%#{location[:state]}")
    end

    if location[:city].present?
      users = users.where('LOWER(location_city) ILIKE LOWER(?)', "%#{location[:city]}")
    end

    csv_string = Reporter.users_export ids: users.pluck(:id), return_csv: true, additional_columns: [:location]

    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: "users-export-#{users.size}-#{Time.now.to_i}.csv"
  end

  def scan
    if params[:username]
      # @user = User.get_by_username(params[:username])
      # @user.update_info!
      #
      # UsersScanWorker.perform_async @user.id
      ScanRequest.create username: params[:username]

      redirect_to users_scan_show_path username: params[:username]
    else
      render layout: 'scan'
    end
  end

  def scan_show
    # @user = User.get_by_username(params[:username])
    # @user.update_info! force: @user.profile_picture.blank?
    #
    # steps_amount = 3
    # steps = 0
    # steps +=1 if @user.grabbed_at.present?
    # steps +=1 if @user.followers_preparedness == 100
    # steps +=1 if @user.get_followers_analytics
    #
    # @update_progress = (steps / steps_amount.to_f * 100).round

    render layout: 'scan'
  end

  def scan_data
    @user = User.get_by_username(params[:username])
    @user.update_info! force: @user.profile_picture.blank?

    if @user.avg_likes_updated_at.blank? || @user.avg_likes_updated_at < 1.month.ago
      UserAvgDataWorker.perform_async @user.id
    end

    if @user.location_updated_at.blank? || @user.location_updated_at < 1.month.ago
      UserLocationWorker.perform_async @user.id
    end

    if @user.followers_updated_at.blank? || @user.followers_updated_at < 1.month.ago
      UserFollowersWorker.perform_async @user.id, ignore_exists: true
    else
      if @user.followers_info_updated_at.blank? || @user.followers_info_updated_at < 1.week.ago
        UserUpdateFollowersWorker.perform_async @user.id
      end
    end

    popular_followers_percentage = nil
    if @user.data_get_value('popular_followers_percentage', lifetime: 2.weeks).present?
      popular_followers_percentage = @user.get_popular_followers_percentage
    else
      popular_followers_percentage = @user.data_get_value('popular_followers_percentage', lifetime: 54.weeks)
      if @user.followers_updated_at && @user.followers_updated_at > 1.month.ago
        UserPopularFollowersWorker.perform_async @user.id
      end
    end

    followers_analytics = nil
    if @user.data_get_value('followers_analytics', lifetime: 2.weeks).present?
      followers_analytics = @user.get_followers_analytics
    else
      followers_analytics = @user.data_get_value('followers_analytics', lifetime: 54.weeks)
      if @user.followers_updated_at && @user.followers_updated_at > 1.month.ago
        UserFollowersAnalyticsWorker.perform_async @user.id
      end
    end

    followers_chart = nil
    if @user.followers_info_updated_at.present? && @user.followers_info_updated_at > 1.month.ago && @user.followers_size >= @user.followed_by * 0.95
      followers_chart = @user.followers_chart_data
    end

    respond_to do |format|
      format.json { render json: {
          profile_picture: @user.profile_picture,
          full_name: @user.full_name,
          website: @user.website,
          location: @user.location,
          email: @user.email,
          avg_likes: @user.avg_likes,
          avg_comments: @user.avg_comments,
          followed_by: @user.followed_by,
          followers_updated_at: (@user.followers_updated_at.strftime('%b %d') if @user.followers_updated_at.present?),
          popular_followers_percentage: popular_followers_percentage,
          followers_analytics: (followers_analytics.to_a if followers_analytics),
          followers_chart: followers_chart
        } }
    end
  end

  def scan_requests
    @requests = ScanRequest.all.order(created_at: :desc).page(params[:page]).per(20)
  end

  def followers
    @user = User.get(params[:username])
    followers_ids = Follower.where(user_id: @user.id).pluck(:follower_id)

    csv_string = CSV.generate do |csv|
      csv << ['Username', 'Full Name', 'URL', 'BIO', 'Follows', 'Followers']
      followers_ids.in_groups_of(100_000, false) do |ids|
        User.where(id: ids).pluck(:username, :full_name, :website, :bio, :follows, :followed_by).each do |u|
          csv << u
        end
      end
    end

    send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: "#{@user.username}-followers-#{Time.now.to_i}.csv"
  end

end
