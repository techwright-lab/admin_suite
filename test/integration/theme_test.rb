# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class ThemeTest < ActionDispatch::IntegrationTest
    test "layout includes scoped theme variables" do
      old = AdminSuite.config.theme
      AdminSuite.config.theme = { primary: :indigo, secondary: :purple }

      get "/internal/admin_suite"
      assert_response :success

      # Theme variables are injected by `admin_suite_theme_style_tag`.
      assert_includes response.body, "--admin-suite-primary:"
      assert_includes response.body, "--admin-suite-sidebar-from:"
    ensure
      AdminSuite.config.theme = old
    end

    test "body is scoped with admin-suite class" do
      get "/internal/admin_suite"
      assert_response :success
      assert_match(/<body[^>]*class=\"[^\"]*admin-suite[^\"]*\"/i, response.body)
    end
  end
end
