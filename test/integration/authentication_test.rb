# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class AuthenticationTest < ActionDispatch::IntegrationTest
    ROOT = "/internal/admin_suite"

    def with_config(**overrides)
      saved = overrides.keys.index_with { |k| AdminSuite.config.public_send(k) }
      overrides.each { |k, v| AdminSuite.config.public_send("#{k}=", v) }
      yield
    ensure
      saved.each { |k, v| AdminSuite.config.public_send("#{k}=", v) }
    end

    test "unconfigured auth fails closed with 403" do
      with_config(allow_unauthenticated: false, auth_strategy: nil, authenticate: nil) do
        get ROOT
        assert_response :forbidden
        assert_includes response.body, "no authentication is configured"
      end
    end

    test "allow_unauthenticated opens access outside production" do
      with_config(allow_unauthenticated: true, auth_strategy: nil, authenticate: nil) do
        get ROOT
        assert_response :success
      end
    end

    test "http_basic strategy denies without credentials and allows with them" do
      with_config(allow_unauthenticated: false, auth_strategy: :http_basic,
                  auth_options: { username: "ravi", password: "s3cret" }) do
        get ROOT
        assert_response :unauthorized # Basic challenge

        get ROOT, headers: {
          "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("ravi", "s3cret")
        }
        assert_response :success
      end
    end

    test "legacy authenticate lambda still works" do
      denials = ->(controller) { controller.head :forbidden }
      with_config(allow_unauthenticated: false, auth_strategy: nil, authenticate: denials) do
        get ROOT
        assert_response :forbidden
      end
    end
  end
end
