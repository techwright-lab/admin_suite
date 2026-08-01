# frozen_string_literal: true

module AdminSuite
  # A navigation section within a portal. Sections group resources in the
  # sidebar; declaring one lets a portal control its label, icon and order
  # instead of accepting the humanized key and alphabetical placement.
  class SectionDefinition
    attr_reader :key

    def initialize(key)
      @key = key.to_sym
      @label = nil
      @icon = nil
      @order = nil
      @description = nil
    end

    def label(value = nil)
      @label = value if value.present?
      @label
    end

    def icon(value = nil)
      @icon = value if value.present?
      @icon
    end

    def order(value = nil)
      @order = value unless value.nil?
      @order
    end

    def description(value = nil)
      @description = value if value.present?
      @description
    end

    def to_nav_meta
      { label: @label, icon: @icon, order: @order, description: @description }.compact
    end
  end
end
