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

    @tags.map do |t|
      if t.media_count < 100
        t.update_column :media_count, t.media.length
      end
    end
  end

  def observed
    @tags = Tag.observed.includes(:observed_tag).order(:name).page(params[:page]).per(20)
    @tags.map do |t|
      if t.media_count < 100
        t.update_column :media_count, t.media.length
      end
    end
  end
end
