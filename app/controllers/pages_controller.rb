class PagesController < ApplicationController

  protect_from_forgery :except => :tag_media_added

  after_action :allow_iframe, only: :chart

  http_basic_authenticate_with name: "rob", password: "awesomeLA", only: :home

  def home

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

    @amount_of_days = Tag::CHART_DAYS

    @amount_of_days.times do |i|
      d = @amount_of_days-i-1
      cat = d.days.ago.utc.strftime('%m/%d')
      blank[cat] = 0
    end

    @xcategories = blank.keys

    @groups = {}

    tags = params['tags']
    tags = tags.split(',') if tags && tags.is_a?(String)

    @tags = tags && tags.size > 0 ? Tag.where(name: tags) : Tag.where(show_graph: 1)
    @tags = @tags.pluck(:name)
  end

  def chart_tag_data
    tag_name = params[:name]

    cache = true
    values = Rails.cache.read("chart-#{tag_name}")
    last_30_days = Rails.cache.read("tag-last-30-days-#{tag_name}")

    if !values || !last_30_days
      TagChartWorker.new.perform tag_name, params[:amount_of_days]
      values = Rails.cache.read("chart-#{tag_name}")
      last_30_days = Rails.cache.read("tag-last-30-days-#{tag_name}")
      cache = false
    end

    # tag = Tag.where(name: tag_name).first
    # last_30_days = TagStat.where('date >= ?', 30.days.ago).where(tag: tag).pluck(:amount).sum
    # last_30_days = TagStat.order(date: :desc).first if last_30_days.blank?

    render json: { data: values, tag: tag_name, cache: cache, last_30_days: last_30_days }
  end

  def clients_status

  end

  def chart_amounts
    @xcategories = []
    blank = {}

    @amount_of_days = Tag::CHART_DAYS

    @amount_of_days.times do |i|
      d = @amount_of_days-i-1
      cat = d.days.ago.utc.strftime('%m/%d')
      blank[cat] = 0
    end

    @xcategories = blank.keys

    # Stat.where()
  end

  private

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
  end
end
