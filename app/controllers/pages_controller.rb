class PagesController < ApplicationController

  protect_from_forgery :except => :tag_media_added

  after_action :allow_iframe, only: :chart

  if Rails.env.production?
    http_basic_authenticate_with name: "rob", password: "awesomeLA", only: :home
  end

  def home
    @observed_amount = ObservedTag.all.size
    @exportable_amount = ObservedTag.where(export_csv: true).size
    @chartable_amount = ObservedTag.where(for_chart: true).size
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

    @tags = tags && tags.size > 0 ? Tag.in(name: tags) : Tag.in(id: ObservedTag.where(for_chart: true).pluck(:tag_id))
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

    render json: { data: values, tag: tag_name, cache: cache, last_30_days: last_30_days }
  end

  def clients_status
    @accounts = InstagramAccount.all.page(params[:page]).per(10)
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

  def media_chart
    @published = MediaAmountStat.where(:date.gt => (params[:days] || 14).days.ago.utc.beginning_of_day, action: :published).order_by(date: :asc).map{|el| [el.date.strftime('%m/%d'), el.amount]}
    @added = MediaAmountStat.where(:date.gt => (params[:days] || 14).days.ago.utc.beginning_of_day, action: :added).order_by(date: :asc).map{|el| [el.date.strftime('%m/%d'), el.amount]}
  end

  private

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
  end
end
