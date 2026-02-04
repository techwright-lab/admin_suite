# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class DashboardTest < ActionDispatch::IntegrationTest
    test "GET /internal/admin_suite renders dashboard" do
      get "/internal/admin_suite"
      assert_response :success
      assert_includes response.body, "Developer Portal"
    end
  end
end
