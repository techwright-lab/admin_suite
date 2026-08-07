# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class AuthTest < ActiveSupport::TestCase
    class FakeStrategy < AdminSuite::Auth::Strategy
      def authenticate!(_controller) = :fake_actor
    end

    test "register and lookup a strategy by name" do
      with_auth_registry_snapshot do
        AdminSuite::Auth.register(:fake, FakeStrategy)
        assert_equal FakeStrategy, AdminSuite::Auth.lookup(:fake)
        assert_equal FakeStrategy, AdminSuite::Auth.lookup("fake")
      end
    end

    test "lookup of unknown strategy raises UnknownStrategyError" do
      assert_raises(AdminSuite::Auth::UnknownStrategyError) do
        AdminSuite::Auth.lookup(:nope)
      end
    end

    test "registered lists registered strategy names" do
      with_auth_registry_snapshot do
        AdminSuite::Auth.register(:fake, FakeStrategy)

        assert_includes AdminSuite::Auth.registered, :fake
        assert_includes AdminSuite::Auth.registered, :http_basic
      end
    end

    test "base strategy exposes options and requires authenticate!" do
      strategy = AdminSuite::Auth::Strategy.new(username: "u")
      assert_equal({ username: "u" }, strategy.options)
      assert_raises(NotImplementedError) { strategy.authenticate!(nil) }
    end

    test "base strategy symbolizes string-keyed options" do
      strategy = AdminSuite::Auth::Strategy.new("username" => "u")

      assert_equal({ username: "u" }, strategy.options)
    end
  end
end
