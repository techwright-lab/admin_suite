# frozen_string_literal: true

require "test_helper"

module AuthorizationContextFixtures
  # A plain object implementing #call -- exactly the shape a host might write
  # as an authorize adapter. Has no #parameters of its own; the writer must
  # fall back to introspecting #call's method object.
  class CorrectArityCallable
    def call(actor:, action:, resource:, record:, context:)
      true
    end
  end

  class OldArityCallable
    def call(actor:, action:, resource:, record:, controller:)
      true
    end
  end

  class SplatCallable
    def call(**)
      true
    end
  end
end

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

    # Assert on the COMPUTED diagnosis, not the message's fixed footer -- that
    # footer explains the controller:/context: migration on every failure, so
    # `assert_match(/controller:/)` alone would pass for any rejection at all.
    assert_match(/Missing: \[:context\]/, error.message)
    assert_match(/Unexpected: \[:controller\]/, error.message)
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

    # The splat means nothing is missing; `controller:` being named is the
    # whole defect, so assert exactly that rather than the shared footer.
    assert_match(/Missing: \[\]/, error.message)
    assert_match(/Unexpected: \[:controller\]/, error.message)
  ensure
    AdminSuite.config.authorize = nil
  end

  test "accepts a correct-arity callable object without #parameters" do
    AdminSuite.config.authorize = AuthorizationContextFixtures::CorrectArityCallable.new
    assert_respond_to AdminSuite.config.authorize, :call
  ensure
    AdminSuite.config.authorize = nil
  end

  test "rejects an old-arity callable object, proving the fallback validates rather than bypasses" do
    error = assert_raises(ArgumentError) do
      AdminSuite.config.authorize = AuthorizationContextFixtures::OldArityCallable.new
    end

    # This test's name claims the fallback VALIDATES rather than bypasses, so
    # it must assert the guard actually read this object's `#call` signature.
    # Matching the footer would also pass for a fallback that rejected every
    # callable outright -- the opposite of validation.
    assert_match(/Missing: \[:context\]/, error.message)
    assert_match(/Unexpected: \[:controller\]/, error.message)
  ensure
    AdminSuite.config.authorize = nil
  end

  test "accepts a callable object whose #call takes a keyword splat" do
    AdminSuite.config.authorize = AuthorizationContextFixtures::SplatCallable.new
    assert_respond_to AdminSuite.config.authorize, :call
  ensure
    AdminSuite.config.authorize = nil
  end

  test "rejects a non-callable with an ArgumentError naming the problem" do
    error = assert_raises(ArgumentError) do
      AdminSuite.config.authorize = "nope"
    end

    assert_match(/callable/, error.message)
    assert_match(/String/, error.message)
  ensure
    AdminSuite.config.authorize = nil
  end
end
