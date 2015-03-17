class TagsController < ApplicationController

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

    @tags = @tags.order(:name).page(params[:page]).per(20)
  end

  def observed
    @tags = Tag.observed.includes(:observed_tag).order(:name).page(params[:page]).per(20)
  end
end
