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

    Tag.where(show_graph: 1).each do |tag|
      @groups[tag.name] = blank.dup
      tag.media.where('created_time >= ?', 9.days.ago.beginning_of_day).pluck(:created_time).each do |row|
        @groups[tag.name][row.strftime('%m/%d')] += 1
      end

      # @groups[tag.name] = blank.dup
      # amount_of_days.times do |i|
      #   day = (amount_of_days-i).days.ago
      #   @groups[tag.name][day.strftime('%m/%d')] =
      #     tag.media.where('created_time >= ?', day.beginning_of_day).where('created_time <= ?', day.end_of_day).size
      # end

    end

    # binding.pry
  end
end
