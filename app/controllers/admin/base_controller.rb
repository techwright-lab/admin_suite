# frozen_string_literal: true

module Admin
  # Base controller for all admin controllers
  #
  # Provides common functionality for admin access control and layout.
  # All admin controllers should inherit from this class.
  #
  # Includes common concerns for pagination, filtering, and stats calculation.
  # These can be optionally included in child controllers as needed.
  #
  # @example
  #   class Admin::UsersController < Admin::BaseController
  #     include Admin::Concerns::Paginatable
  #     include Admin::Concerns::Filterable
  #     include Admin::Concerns::StatsCalculator
  #
  #     PER_PAGE = 30
  #
  #     def index
  #       @users = paginate(filtered_users)
  #       @stats = calculate_stats
  #       @filters = filter_params
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
