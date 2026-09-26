class StoriesController < ApplicationController
  def index
    @stories = Story.feed.includes(:biblical_analysis)
  end

  def show
    @story = Story.published.includes(:biblical_analysis).find(params[:id])
    @analysis = @story.biblical_analysis
    @verses = @analysis&.looked_up_verses || []
  rescue ActiveRecord::RecordNotFound
    render "stories/not_found", status: :not_found
  end
end
