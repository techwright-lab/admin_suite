# frozen_string_literal: true

module AdminSuite
  # Stores portal definitions registered via `AdminSuite.portal`.
  module PortalRegistry
    class << self
      # @return [Hash{Symbol=>AdminSuite::PortalDefinition}]
      def all
        @all ||= {}
      end

      # @param definition [AdminSuite::PortalDefinition]
      # @return [AdminSuite::PortalDefinition]
      def register(definition)
        all[definition.key] = definition
      end

      # @param key [Symbol, String]
      # @return [AdminSuite::PortalDefinition, nil]
      def fetch(key)
        all[key.to_sym]
      end

      # Clears the registry (useful for development reloads).
      #
      # @return [void]
      def reset!
        @all = {}
      end
    end
  end
end
