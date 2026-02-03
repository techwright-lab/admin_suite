# frozen_string_literal: true

module Admin
  module Base
    # Calculates statistics for admin resource index pages
    #
    # Uses the stat definitions from the resource's index configuration
    # to generate a hash of calculated statistics.
    #
    # @example
    #   calculator = Admin::Base::StatsCalculator.new(CompanyResource)
    #   stats = calculator.calculate
    #   # => { total: 150, with_website: 120, with_job_listings: 45 }
    class StatsCalculator
      attr_reader :resource_class

      # Initializes the stats calculator
      #
      # @param resource_class [Class] The resource class with stat definitions
      def initialize(resource_class)
        @resource_class = resource_class
      end

      # Calculates all defined statistics
      #
      # @return [Hash] Hash of stat names to calculated values
      def calculate
        return {} unless index_config
        return {} if index_config.stats_list.empty?

        stats = {}

        index_config.stats_list.each do |stat_def|
          stats[stat_def.name] = calculate_stat(stat_def)
        end

        stats
      end

      # Returns stat colors for display
      #
      # @return [Hash] Hash of stat names to color classes
      def colors
        return {} unless index_config

        colors = {}

        index_config.stats_list.each do |stat_def|
          next unless stat_def.color

          colors[stat_def.name] = color_class_for(stat_def.color)
        end

        colors
      end

      private

      def index_config
        @resource_class.index_config
      end

      def calculate_stat(stat_def)
        if stat_def.calculator.is_a?(Proc)
          stat_def.calculator.call
        elsif stat_def.calculator.is_a?(Symbol)
          model_class.public_send(stat_def.calculator)
        else
          stat_def.calculator
        end
      rescue StandardError => e
        Rails.logger.error "Failed to calculate stat #{stat_def.name}: #{e.message}"
        "N/A"
      end

      def model_class
        @resource_class.model_class
      end

      def color_class_for(color)
        case color.to_sym
        when :blue
          "text-blue-600 dark:text-blue-400"
        when :green
          "text-green-600 dark:text-green-400"
        when :amber, :yellow
          "text-amber-600 dark:text-amber-400"
        when :red
          "text-red-600 dark:text-red-400"
        when :purple
          "text-purple-600 dark:text-purple-400"
        when :slate, :gray
          "text-slate-600 dark:text-slate-400"
        else
          "text-slate-900 dark:text-white"
        end
      end
    end
  end
end
