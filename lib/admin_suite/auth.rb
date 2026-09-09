# frozen_string_literal: true

require "admin_suite/auth/strategy"

module AdminSuite
  # Registry of named authentication strategies.
  module Auth
    class UnknownStrategyError < StandardError; end

    @registry = {}

    class << self
      def register(name, klass)
        @registry[name.to_sym] = klass
      end

      def lookup(name)
        @registry.fetch(name.to_sym) do
          raise UnknownStrategyError,
            "Unknown AdminSuite auth strategy #{name.inspect}. Registered: #{@registry.keys.sort.inspect}"
        end
      end

      def registered
        @registry.keys
      end

      # One definition of "is this a usable actor?", shared by every surface.
      #
      # Legacy `HostHook` returns `true` to mean "authenticated, but I could
      # not name anybody". That is an answer to a different question than
      # authorization asks, so it is not an actor. Lives here rather than in
      # a controller so the MCP surface -- which has no controller -- cannot
      # drift from the web UI's interpretation.
      def normalize_actor(value)
        return nil if value.nil? || value.equal?(true) || value.equal?(false)

        value
      end
    end
  end
end

require "admin_suite/auth/http_basic"
require "admin_suite/auth/host_hook"
require "admin_suite/auth/host_user"
AdminSuite::Auth.register(:http_basic, AdminSuite::Auth::HttpBasic)
AdminSuite::Auth.register(:host_user, AdminSuite::Auth::HostUser)
