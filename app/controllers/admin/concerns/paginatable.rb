# frozen_string_literal: true

module Admin
  module Concerns
    # Concern for pagination functionality in admin controllers
    #
    # Uses Pagy for standardized pagination that can be included in any
    # admin controller that needs paginated index actions.
    #
    # @example
    #   class Admin::UsersController < Admin::BaseController
    #     include Admin::Concerns::Paginatable
    #
    #     def index
    #       @pagy, @users = paginate(filtered_users, limit: 30)
    #     end
    #   end
    module Paginatable
      extend ActiveSupport::Concern

      include Pagy::Backend

      # Default items per page for admin views
      DEFAULT_LIMIT = 25

      private

      # Paginates a collection using Pagy
      #
      # @param collection [ActiveRecord::Relation] The collection to paginate
      # @param limit [Integer] Items per page (defaults to DEFAULT_LIMIT)
      # @return [Array<Pagy, ActiveRecord::Relation>] Pagy object and paginated collection
      def paginate(collection, limit: DEFAULT_LIMIT)
        pagy(collection, limit: limit)
      end
    end
  end
end
