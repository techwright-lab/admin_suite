# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

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

    test "allow_unauthenticated is ignored in production" do
      with_config(allow_unauthenticated: true, auth_strategy: nil, authenticate: nil) do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
          get ROOT
          assert_response :forbidden
          assert_includes response.body, "no authentication is configured"
        end
      end
    end

    test "current_actor is consulted at most once per request on the legacy path" do
      calls = 0
      passes = ->(_controller) {}
      counting_actor = lambda { |_controller|
        calls += 1
        nil
      }

      with_config(allow_unauthenticated: false, auth_strategy: nil, authenticate: passes,
                  current_actor: counting_actor) do
        get ROOT
        assert_response :success
        assert_equal 1, calls
      end
    end

    test "legacy authenticate lambda passes but a raising current_actor lambda is rescued to nil" do
      passes = ->(_controller) {}
      raising_actor = ->(_controller) { raise "boom" }

      with_config(allow_unauthenticated: false, auth_strategy: nil, authenticate: passes,
                  current_actor: raising_actor) do
        get ROOT
        assert_response :success
      end
    end

    test "host filter skip list is config-driven with require_authentication default" do
      assert_equal [ :require_authentication ], AdminSuite.config.skip_host_before_actions
      # The controller must consume config rather than hardcode the name:
      source = AdminSuite::Engine.root.join("app/controllers/admin_suite/application_controller.rb").read
      assert_includes source, "skip_host_before_actions"
      refute_match(/skip_before_action :require_authentication\b/, source)
    end
  end
end
