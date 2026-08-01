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

      # Test-support only. Removes a single registration.
      #
      # There is intentionally no bulk `reset!`: AdminSuite's own built-in
      # renderers (Task 4) register themselves into this same module-level
      # hash at require time, once, for the life of the process. A `reset!`
      # that cleared the whole registry would wipe those alongside whatever
      # a test added. Specs that register scratch/probe renderers should
      # call `unregister` for exactly the key(s) they added, in a teardown.
      def unregister(key)
        @registry.delete(key.to_sym)
      end
    end
  end
end
