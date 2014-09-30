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
    tag_name = params[:name]

    cache = true
    values = Rails.cache.read("chart-#{tag_name}")
    unless values
      values = TagChartWorker.new.perform tag_name
      # tag = Tag.find_by_name tag_name
      # values = tag.chart_data
      # Rails.cache.write("chart-#{tag.name}", values, expires_in: 6.hours)
      cache = false
    end

    render json: { data: values, tag: tag_name, cache: cache }
  end
end
