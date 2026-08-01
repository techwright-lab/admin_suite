# frozen_string_literal: true

module AdminSuite
  # Maps panel `render:` keys to Renderer classes.
  module RendererRegistry
    @registry = {}

    class << self
      def register(key, klass)
        @registry[key.to_sym] = klass
      end

      # @return [Class, nil]
      def lookup(key)
        @registry[key.to_sym]
      end

      def registered
        @registry.keys
      end
    end
  end
end
