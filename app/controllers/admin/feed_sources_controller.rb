module Admin
  class FeedSourcesController < BaseController
    def toggle
      source = FeedSource.find(params[:id])
      source.update!(enabled: !source.enabled)
      redirect_to admin_settings_path, notice: "#{source.name} #{source.enabled? ? 'enabled' : 'disabled'}."
    end
  end
end
