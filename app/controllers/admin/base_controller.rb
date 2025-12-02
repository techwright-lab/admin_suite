# frozen_string_literal: true

module Admin
  # Base controller for all admin controllers
  #
  # Provides common functionality for admin access control and layout.
  # All admin controllers should inherit from this class.
  #
  # @example
  #   class Admin::MetricsController < Admin::BaseController
  #     def index
  #       # Admin-only action
  #     end
  #   end
  class BaseController < ApplicationController
    before_action :require_admin!

    layout "admin"

    private

    # Requires admin privileges to access the controller
    #
    # Redirects non-admin users to root with an alert message.
    # @return [void]
    def require_admin!
      unless Current.user&.admin?
        redirect_to root_path, alert: "You don't have permission to access this area."
      end
    end
  end
end

