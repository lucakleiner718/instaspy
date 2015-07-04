class TagsController < ApplicationController

  helper_method :sort_column, :sort_direction

  def index
    @tags = Tag.all

    case params[:filter]
      when 'observed'
        @tags = @tags.observed
      when 'csv'
        @tags = @tags.exportable
      when 'charts'
        @tags = @tags.chartable
    end

    params[:sort] ||= :name
    params[:direction] ||= :asc
    @tags = @tags.order("#{params[:sort]} #{params[:direction]}")

    @tags = @tags.page(params[:page]).per(20)
  end

  def observed
    redirect_to tags_path(filter: :observed)
  end

  def observe

  end

  def observe_process
    tags = params[:tags].split("\r\n")
    tags.each do |tag_name|
      Tag.observe tag_name
    end
    redirect_to tags_path(filter: :observed)
  end

  private

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end

  def sort_column
    (Tag.fields.keys - ['_id'] + ['media_count']).include?(params[:sort]) ? params[:sort] : "name"
  end
end
