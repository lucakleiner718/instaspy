class TagsController < ApplicationController

  def observed
    @tags = Tag.observed.includes(:observed_tag).order(:name).page(params[:page]).per(20)
  end
end
