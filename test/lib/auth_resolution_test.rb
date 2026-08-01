# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class AuthResolutionTest < ActiveSupport::TestCase
    class PerformableDouble
      def initialize(performed:) = @performed = performed
      def performed? = @performed
    end

    setup do
      @saved = {
        auth_strategy: AdminSuite.config.auth_strategy,
        auth_options: AdminSuite.config.auth_options,
        authenticate: AdminSuite.config.authenticate,
        current_actor: AdminSuite.config.current_actor
      }
    end

    teardown do
      @saved.each { |k, v| AdminSuite.config.public_send("#{k}=", v) }
    end

    test "config defaults are fail-closed friendly" do
      fresh = AdminSuite::Configuration.new
      assert_nil fresh.auth_strategy
      assert_equal({}, fresh.auth_options)
      assert_equal false, fresh.allow_unauthenticated
      assert_equal [ :require_authentication ], fresh.skip_host_before_actions
    end

    test "resolves a symbol strategy through the registry with options" do
      AdminSuite.config.auth_strategy = :http_basic
      AdminSuite.config.auth_options = { username: "u", password: "p" }

      strategy = AdminSuite.resolved_auth_strategy

      assert_instance_of Auth::HttpBasic, strategy
      assert_equal "u", strategy.options[:username]
    end

    test "resolves a class strategy directly" do
      klass = Class.new(Auth::Strategy)
      AdminSuite.config.auth_strategy = klass
      assert_instance_of klass, AdminSuite.resolved_auth_strategy
    end

    test "wraps legacy authenticate lambda when no strategy is set" do
      AdminSuite.config.auth_strategy = nil
      AdminSuite.config.authenticate = ->(_controller) { :called }
      AdminSuite.config.current_actor = ->(_controller) { :legacy_actor }

      strategy = AdminSuite.resolved_auth_strategy
      assert_instance_of Auth::HostHook, strategy

      actor = strategy.authenticate!(PerformableDouble.new(performed: false))
      assert_equal :legacy_actor, actor
    end

    test "legacy lambda that halts (renders/redirects) denies" do
      AdminSuite.config.auth_strategy = nil
      AdminSuite.config.authenticate = ->(_controller) { :redirected_inside }

      strategy = AdminSuite.resolved_auth_strategy
      assert_nil strategy.authenticate!(PerformableDouble.new(performed: true))
    end

    test "returns nil when nothing configured" do
      AdminSuite.config.auth_strategy = nil
      AdminSuite.config.authenticate = nil
      assert_nil AdminSuite.resolved_auth_strategy
    end
  end
end
