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

  def show
    @user = User.find_by(username: params[:id])

    data = Follower.collection.aggregate(
      { "$match" => { user_id: @user.id, followed_at: { '$ne' => nil } } },
      { "$group" => {
        _id: { month: { "$month" => "$followed_at" }, year: { "$year" => "$followed_at" } },
        count: { "$sum" => 1 } } },
      { "$sort" => { followed_at: 1 } }
    )
    data = data.inject({}) do |obj, el|
      date = DateTime.parse("#{el['_id']['year']}/#{el['_id']['month']}/1").to_i * 1000
      obj[date] = el['count']
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
end
