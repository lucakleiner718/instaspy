class PagesController < ApplicationController

  protect_from_forgery :except => :tag_media_added

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
    unless values
      values = TagChartWorker.new.perform tag_name, params[:amount_of_days]
      # tag = Tag.find_by_name tag_name
      # values = tag.chart_data
      # Rails.cache.write("chart-#{tag.name}", values, expires_in: 6.hours)
      cache = false
    end

    tag = Tag.where(name: tag_name).first
    last_30_days = TagStat.where('date >= ?', 30.days.ago).where(tag: tag).pluck(:amount).sum

    render json: { data: values, tag: tag_name, cache: cache, last_30_days: last_30_days }
  end

  def clients_status

  end

  # def tag_media_added_check
  #   if params['hub.mode'] == 'subscribe' && params['hub.challenge'].present?
  #     render text: Instagram.meet_challenge(params, 'text1')
  #   else
  #     render text: ''
  #   end
  # end
  #
  # def tag_media_added
  #
  #   # binding.pry
  #   client = InstaClient.new.client
  #
  #   params['_json'].each do |el|
  #     if el['changed_aspect'] == 'media'
  #       if el['object'] == 'tag'
  #         tag = el['object_id']
  #       end
  #     end
  #   end
  #
  #   @media_list = client.tag_recent_media(self.name, min_tag_id: options[:min_id], max_tag_id: options[:max_id], count: 1000)
  #
  #   @media_list.data.each do |media_item|
  #     media = Media.where(insta_id: media_item['id']).first_or_initialize
  #
  #     user = User.where(insta_id: media_item['user']['id']).first_or_initialize
  #     user.username = media_item['user']['username']
  #     user.full_name = media_item['user']['full_name']
  #     user.save
  #
  #     media.user_id = user.id
  #     media.created_time = Time.at media_item['created_time'].to_i
  #
  #     tags = []
  #     media_item['tags'].each do |tag_name|
  #       tags << Tag.where(name: tag_name).first_or_create
  #     end
  #     media.tags = tags
  #
  #     media.save
  #   end
  #
  # end

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
end
