# frozen_string_literal: true

require "admin_suite/ui/dashboard_definition"

module AdminSuite
  class PortalDefinition
    attr_reader :key

    def initialize(key)
      @key = key.to_sym
      @label = nil
      @icon = nil
      @color = nil
      @order = nil
      @description = nil
      @dashboard = nil
    end

    def label(value = nil)
      @label = value if value.present?
      @label
    end

    def icon(value = nil)
      @icon = value if value.present?
      @icon
    end

    def color(value = nil)
      @color = value if value.present?
      @color
    end

    def order(value = nil)
      @order = value unless value.nil?
      @order
    end

    def description(value = nil)
      @description = value if value.present?
      @description
    end

    def dashboard(&block)
      @dashboard ||= UI::DashboardDefinition.new
      UI::DashboardDSL.new(@dashboard).instance_eval(&block) if block_given?
      @dashboard
    end

    def dashboard_definition
      @dashboard
    end

    def to_nav_meta
      {
        label: @label,
        icon: @icon,
        color: @color,
        order: @order,
        description: @description
      }.compact
    end
  end
end
