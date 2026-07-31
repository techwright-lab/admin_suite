# frozen_string_literal: true

module AdminSuite
  module Auth
    # Base class for authentication strategies.
    #
    # A strategy authenticates the current request. It must either:
    # - return a truthy actor object (request allowed), or
    # - deny: render/redirect on the controller itself (halts the chain),
    #   or return nil/false (the engine responds 403).
    class Strategy
      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      # @param controller [ActionController::Base]
      # @return [Object, nil] the authenticated actor, or nil when denied
      def authenticate!(controller)
        raise NotImplementedError, "#{self.class.name} must implement #authenticate!(controller)"
      end
    end
  end
end
