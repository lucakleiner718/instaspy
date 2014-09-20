class PagesController < ApplicationController
  def home
    # redirect_to oauth_connect_path if Setting.g('instagram_access_token').blank?
  end

  def export
    @users = User.order(:full_name)
    respond_to do |format|
      format.csv { render csv: @users }
    end
  end

  def chart
    @xcategories = []
    blank = {}

    amount_of_days = 10

    amount_of_days.times do |i|
      d = amount_of_days-i-1
      cat = d.days.ago.strftime('%m/%d')
      blank[cat] = 0
    end

    @xcategories = blank.keys

    @groups = {}

    @tags = Tag.where(show_graph: 1).pluck(:name)
  end

  def chart_tag_data
    tag = Tag.find_by_name params[:name]

    cache = true
    values = Rails.cache.read("chart-#{tag.name}")
    unless values
    # if true
      blank = {}

      amount_of_days = 10

      amount_of_days.times do |i|
        d = amount_of_days-i-1
        cat = d.days.ago.strftime('%m/%d')
        blank[cat] = 0
      end

      # @xcategories = blank.keys


      data = blank.dup

      # start = Time.now.to_i
      # tag.media.where('created_time >= ?', 9.days.ago.beginning_of_day).pluck(:created_time).each do |row|
      #   data[row.strftime('%m/%d')] += 1
      # end
      # p (Time.now.to_i - start)

      # start = Time.now.to_i
      amount_of_days.times do |i|
        day = (amount_of_days-i-1).days.ago.utc
        data[day.strftime('%m/%d')] =
          tag.media.where('created_time >= ?', day.beginning_of_day).where('created_time <= ?', day.end_of_day).size
      end
      # p (Time.now.to_i - start)

      data = data.reject{|k| !k.in?(blank) }

      values = data.values

      Rails.cache.write("chart-#{tag.name}", values, expires_in: 10.minutes)
      cache = false
    end

    render json: { data: values, tag: tag.name, cache: cache }
  end
end
