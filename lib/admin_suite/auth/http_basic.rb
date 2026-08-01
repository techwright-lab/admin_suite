# frozen_string_literal: true

module AdminSuite
  module Auth
    # Built-in HTTP Basic authentication.
    #
    # Credentials come from options or environment:
    #   config.auth_strategy = :http_basic
    #   config.auth_options  = { username: "...", password: "..." }
    # or ADMIN_SUITE_USERNAME / ADMIN_SUITE_PASSWORD.
    #
    # Blank credentials deny every request — enabling the strategy without
    # configuring credentials must never leave the admin open.
    class HttpBasic < Strategy
      Actor = Struct.new(:username) do
        def name = username
        def to_s = "http-basic:#{username}"
      end

      def authenticate!(controller)
        username = options[:username].presence || ENV["ADMIN_SUITE_USERNAME"]
        password = options[:password].presence || ENV["ADMIN_SUITE_PASSWORD"]

        if username.blank? || password.blank?
          controller.render(
            plain: "AdminSuite: HTTP Basic auth is enabled but no credentials are configured. " \
                   "Set ADMIN_SUITE_USERNAME and ADMIN_SUITE_PASSWORD (or config.auth_options).",
            status: :forbidden
          )
          return nil
        end

        authenticated = controller.authenticate_with_http_basic do |given_user, given_pass|
          # Single `&` (not `&&`) so both comparisons always run (constant time).
          ActiveSupport::SecurityUtils.secure_compare(given_user.to_s, username) &
            ActiveSupport::SecurityUtils.secure_compare(given_pass.to_s, password)
        end

        return Actor.new(username) if authenticated

        controller.request_http_basic_authentication("AdminSuite")
        nil
      end
    end
  end
end
