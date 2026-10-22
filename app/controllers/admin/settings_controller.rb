module Admin
  class SettingsController < BaseController
    def show
      @setting = EditorialSetting.current
      @feed_sources = FeedSource.order(:name)
    end

    def update
      @setting = EditorialSetting.current
      if @setting.update(setting_params)
        SelectStoriesJob.perform_later(reshuffle: true)
        redirect_to admin_settings_path, notice: "Saved. Focus is #{@setting.focus_label}; the story queue is being reshuffled."
      else
        @feed_sources = FeedSource.order(:name)
        render :show, status: :unprocessable_entity
      end
    end

    private
      def setting_params
        params.expect(editorial_setting: %i[focus gnews_queries_text min_prophecy_relevance daily_publish_cap])
      end
  end
end
