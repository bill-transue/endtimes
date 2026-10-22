module Admin
  class StoriesController < BaseController
    def index
      @filter = params[:status].presence
      @stories = Story.includes(:biblical_analysis).admin_queue
      @stories = @stories.where(status: @filter) if @filter.present? && Story.statuses.key?(@filter)
    end

    def publish
      change_status(:published)
    end

    def hold
      change_status(:held)
    end

    def reject
      change_status(:rejected)
    end

    private
      def change_status(status)
        story = Story.find(params[:id])
        story.editor_set_status!(status)
        redirect_to admin_stories_path(status: params[:status]), notice: "#{story.title.truncate(72)} marked #{story.status}."
      end
  end
end
