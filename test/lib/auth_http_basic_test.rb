# frozen_string_literal: true

raise "unset ADMIN_SUITE_USERNAME in test env" if ENV["ADMIN_SUITE_USERNAME"]

require "test_helper"

module AdminSuite
  class AuthHttpBasicTest < ActiveSupport::TestCase
    # Minimal stand-in for the parts of ActionController the strategy touches.
    class ControllerDouble
      attr_reader :rendered_status, :challenged

      def initialize(given_username: nil, given_password: nil)
        @given_username = given_username
        @given_password = given_password
      end

      def authenticate_with_http_basic
        return false if @given_username.nil?
        yield(@given_username, @given_password)
      end

      def render(plain:, status:)
        @rendered_status = status
      end

      def request_http_basic_authentication(_realm)
        @challenged = true
      end
    end

    test "returns an actor for correct credentials" do
      strategy = Auth::HttpBasic.new(username: "ravi", password: "s3cret")
      controller = ControllerDouble.new(given_username: "ravi", given_password: "s3cret")

      actor = strategy.authenticate!(controller)

      assert_equal "ravi", actor.username
      assert_equal "http-basic:ravi", actor.to_s
    end

    test "challenges on wrong credentials and returns nil" do
      strategy = Auth::HttpBasic.new(username: "ravi", password: "s3cret")
      controller = ControllerDouble.new(given_username: "ravi", given_password: "wrong")

      assert_nil strategy.authenticate!(controller)
      assert controller.challenged
    end

    test "denies with 403 when credentials are not configured" do
      strategy = Auth::HttpBasic.new(username: nil, password: nil)
      controller = ControllerDouble.new(given_username: "any", given_password: "any")

      assert_nil strategy.authenticate!(controller)
      assert_equal :forbidden, controller.rendered_status
    end

    test "is registered as :http_basic" do
      assert_equal Auth::HttpBasic, Auth.lookup(:http_basic)
    end
  end
end
