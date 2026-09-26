class ApplicationController < ActionController::Base
  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :page_title

  private
    def page_title
      content_for(:title).presence || "End Times"
    end
end
