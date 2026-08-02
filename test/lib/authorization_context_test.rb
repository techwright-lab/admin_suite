# frozen_string_literal: true

require "test_helper"

class AuthorizationContextTest < ActiveSupport::TestCase
  test "reports its surface" do
    web = AdminSuite::AuthorizationContext.new(surface: :web, controller: :ctrl)
    mcp = AdminSuite::AuthorizationContext.new(surface: :mcp)

    assert_predicate web, :web?
    refute_predicate web, :mcp?
    assert_equal :ctrl, web.controller
    assert_predicate mcp, :mcp?
    assert_nil mcp.controller
  end

  test "rejects an unknown surface" do
    assert_raises(ArgumentError) { AdminSuite::AuthorizationContext.new(surface: :carrier_pigeon) }
  end

  test "assigning an old-arity authorize hook raises immediately" do
    error = assert_raises(ArgumentError) do
      AdminSuite.config.authorize = ->(actor:, action:, resource:, record:, controller:) { true }
    end

    assert_match(/context:/, error.message)
    assert_match(/controller:/, error.message)
  ensure
    AdminSuite.config.authorize = nil
  end

  test "accepts a correct-arity hook and a nil hook" do
    AdminSuite.config.authorize = ->(actor:, action:, resource:, record:, context:) { true }
    assert_respond_to AdminSuite.config.authorize, :call
    AdminSuite.config.authorize = nil
    assert_nil AdminSuite.config.authorize
  end

  test "accepts a hook that takes a keyword splat" do
    AdminSuite.config.authorize = ->(**) { true }
    assert_respond_to AdminSuite.config.authorize, :call

    AdminSuite.config.authorize = ->(action:, **) { action == :read }
    assert_respond_to AdminSuite.config.authorize, :call
  ensure
    AdminSuite.config.authorize = nil
  end

  test "still rejects controller: even behind a splat" do
    error = assert_raises(ArgumentError) do
      AdminSuite.config.authorize = ->(controller:, **) { true }
    end

    assert_match(/controller:/, error.message)
  ensure
    AdminSuite.config.authorize = nil
  end
end
