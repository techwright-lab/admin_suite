# frozen_string_literal: true

module Admin
  module Concerns
    # Concern for filtering functionality in admin controllers
    #
    # Provides standardized filter parameter handling that can be included
    # in any admin controller that needs filtering on index actions.
    #
    # @example
    #   class Admin::UsersController < Admin::BaseController
    #     include Admin::Concerns::Filterable
    #
    #     def index
    #       @users = paginate(filtered_users)
    #       @filters = filter_params
    #     end
    #
    #     private
    #
    #     def filtered_users
    #       users = User.all
    #       users = users.where(status: filter_params[:status]) if filter_params[:status].present?
    #       users
    #     end
    #
    #     def filter_params
    #       params.permit(:status, :search, :sort)
    #     end
    #   end
    module Filterable
      extend ActiveSupport::Concern

      private

      # Returns the current filter parameters
      #
      # Override this method in your controller to permit specific filter params.
      # By default, it permits common filter params.
      #
      # @return [ActionController::Parameters] Permitted filter parameters
      def filter_params
        params.permit(:search, :sort, :page)
      end
    end
  end
end
