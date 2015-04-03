class TagsController < ApplicationController

  helper_method :sort_column, :sort_direction

  def index
    @tags = Tag.all

    case params[:filter]
      when 'observed'
        @tags = @tags.observed.includes(:observed_tag)
      when 'csv'
        @tags = @tags.exportable
      when 'charts'
        @tags = @tags.chartable
    end

    if params[:sort]
      @tags = @tags.order("#{params[:sort]} #{params[:direction]}")
    end

    @tags = @tags.order(:name).page(params[:page]).per(20)

    if params[:filter] != 'observed'
      @tags.map do |t|
        if t.media_count < 100
          t.update_column :media_count, t.media.length
        end
      end
    end
  end

  def observed
    redirect_to tags_path(filter: :observed)
  end

  private

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
  end

  def sort_column
    Tag.column_names.include?(params[:sort]) ? params[:sort] : "name"
  end
end
