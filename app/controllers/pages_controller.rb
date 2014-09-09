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

    10.times do |i|
      cat = (9-i).days.ago.strftime('%m/%d')
      @xcategories << cat
      blank[cat] = 0
    end

    @groups = {}

    Tag.where(show_graph: 1).each do |tag|
      @groups[tag.name] = blank.dup
      tag.media.where('created_time >= ?', 9.days.ago.beginning_of_day).each do |row|
        @groups[tag.name][row.created_time.strftime('%m/%d')] += 1
      end
    end

    # binding.pry
  end
end
