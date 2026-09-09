# frozen_string_literal: true

require "test_helper"

class AuthNormalizeActorTest < ActiveSupport::TestCase
  test "normalizes the authenticated-but-anonymous sentinel to nil" do
    assert_nil AdminSuite::Auth.normalize_actor(true)
    assert_nil AdminSuite::Auth.normalize_actor(false)
    assert_nil AdminSuite::Auth.normalize_actor(nil)
  end

  test "passes a real actor through untouched" do
    user = Struct.new(:email).new("ravi@techwright.io")
    assert_same user, AdminSuite::Auth.normalize_actor(user)
  end
end

class AuthHostUserTest < ActiveSupport::TestCase
  Controller = Struct.new(:performed) do
    def performed? = !!performed
    def head(*) = nil
  end

  test "is registered under :host_user" do
    assert_equal AdminSuite::Auth::HostUser, AdminSuite::Auth.lookup(:host_user)
  end

  test "returns the host user the resolver produced" do
    user = Struct.new(:email).new("ravi@techwright.io")
    strategy = AdminSuite::Auth::HostUser.new(resolve: ->(_c) { user })

    assert_same user, strategy.authenticate!(Controller.new(false))
  end

  test "denies when the resolver returns nothing" do
    strategy = AdminSuite::Auth::HostUser.new(resolve: ->(_c) { nil })

    assert_nil strategy.authenticate!(Controller.new(false))
  end

  test "denies rather than raising when the resolver blows up" do
    strategy = AdminSuite::Auth::HostUser.new(resolve: ->(_c) { raise "boom" })

    assert_nil strategy.authenticate!(Controller.new(false))
  end

  test "denies loudly when no resolver is configured" do
    strategy = AdminSuite::Auth::HostUser.new({})

    assert_nil strategy.authenticate!(Controller.new(false))
  end
end
