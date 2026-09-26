module Admin
  class BaseController < ApplicationController
    before_action :authenticate_admin

    private
      def authenticate_admin
        username = ENV["ADMIN_USERNAME"].presence || (Rails.env.local? ? "admin" : nil)
        password = ENV["ADMIN_PASSWORD"].presence || (Rails.env.local? ? "endtimes" : nil)

        if username.blank? || password.blank?
          render plain: "Admin is not configured. Set ADMIN_USERNAME and ADMIN_PASSWORD.", status: :service_unavailable
          return
        end

        authenticate_or_request_with_http_basic("End Times admin") do |given_user, given_password|
          ActiveSupport::SecurityUtils.secure_compare(given_user, username) &
            ActiveSupport::SecurityUtils.secure_compare(given_password, password)
        end
      end
  end
end
