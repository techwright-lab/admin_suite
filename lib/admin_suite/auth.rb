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
    end
  end
end

require "admin_suite/auth/http_basic"
require "admin_suite/auth/host_hook"
AdminSuite::Auth.register(:http_basic, AdminSuite::Auth::HttpBasic)
