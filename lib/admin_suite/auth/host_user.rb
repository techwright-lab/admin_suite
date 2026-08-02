# frozen_string_literal: true

module AdminSuite
  module Auth
    # Authenticates against the host application's own user.
    #
    # This is the standard strategy and the one the docs lead with: most
    # adopters already have a users table with a role, or a separate
    # admin/developer user type. HTTP Basic and any future mechanism are
    # additional.
    #
    #   config.auth_strategy = :host_user
    #   config.auth_options  = { resolve: ->(controller) { controller.current_user } }
    #
    # The resolver returns the host's user object, or nil to deny. Whatever
    # it returns is passed through `Auth.normalize_actor`, so `config.authorize`
    # always receives a real object or nil -- never a bare `true`.
    class HostUser < Strategy
      def authenticate!(controller)
        resolver = options[:resolve]

        unless resolver.respond_to?(:call)
          Rails.logger&.error(
            "AdminSuite: auth_strategy :host_user requires config.auth_options[:resolve] " \
            "(a callable taking the controller). Denying every request until it is set."
          )
          return nil
        end

        actor =
          begin
            resolver.call(controller)
          rescue StandardError => e
            Rails.logger&.warn("AdminSuite: :host_user resolver raised #{e.class}: #{e.message}; denying.")
            nil
          end

        Auth.normalize_actor(actor)
      end
    end
  end
end
