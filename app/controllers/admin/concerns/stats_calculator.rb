# frozen_string_literal: true

module Admin
  module Concerns
    # Concern for calculating statistics in admin controllers
    #
    # Provides a standardized way to calculate and display stats on index pages.
    # Override the `calculate_stats` method in your controller to provide
    # custom statistics.
    #
    # @example
    #   class Admin::UsersController < Admin::BaseController
    #     include Admin::Concerns::StatsCalculator
    #
    #     def index
    #       @stats = calculate_stats
    #     end
    #
    #     private
    #
    #     def calculate_stats
    #       {
    #         total: User.count,
    #         active: User.active.count,
    #         inactive: User.inactive.count
    #       }
    #     end
    #   end
    module StatsCalculator
      extend ActiveSupport::Concern

      private

      # Calculates statistics for display
      #
      # Override this method in your controller to provide custom statistics.
      # By default, returns an empty hash.
      #
      # @return [Hash] Statistics hash
      def calculate_stats
        {}
      end
    end
  end
end
