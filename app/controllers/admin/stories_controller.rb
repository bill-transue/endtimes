module Admin
  class StoriesController < BaseController
    def index
      @filter = params[:status].presence
      @stories = Story.includes(:biblical_analysis).admin_queue
      @stories = @stories.where(status: @filter) if @filter.present? && Story.statuses.key?(@filter)
    end

    def publish
      change_status(:publish!)
    end

    def hold
      change_status(:hold!)
    end

    def reject
      change_status(:reject!)
    end

    private
      def change_status(action)
        story = Story.find(params[:id])
        story.public_send(action)
        redirect_to admin_stories_path(status: params[:status]), notice: "#{story.title.truncate(72)} marked #{story.status}."
      end
  end
end
