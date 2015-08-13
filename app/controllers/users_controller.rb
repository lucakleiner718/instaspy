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
      @user = User.get_by_username(params[:username])
      @user.update_info!

      UsersScanWorker.perform_async @user.id
      ScanRequest.create username: params[:username]

      redirect_to users_scan_show_path username: params[:username]
    else
      render layout: 'scan'
    end
  end

  def scan_show
    @user = User.get_by_username(params[:username])
    @user.update_info!
    render layout: 'scan'
  end

  def scan_requests
    @requests = ScanRequest.all.order(created_at: :desc).page(params[:page]).per(20)
  end

end
