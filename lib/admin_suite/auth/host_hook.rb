# frozen_string_literal: true

module AdminSuite
  module Auth
    # Back-compat wrapper for the legacy `config.authenticate` lambda.
    #
    # Legacy lambdas deny by rendering/redirecting on the controller
    # themselves; success is "the lambda returned without halting".
    class HostHook < Strategy
      def authenticate!(controller)
        options[:authenticate].call(controller)
        return nil if controller.performed?

        actor_hook = options[:current_actor]
        actor = actor_hook&.call(controller)
        actor || true # authenticated, anonymous actor
      end
    end
  end
end
