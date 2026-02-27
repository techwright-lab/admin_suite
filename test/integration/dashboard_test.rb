# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module AdminSuite
  class DashboardTest < ActionDispatch::IntegrationTest
    test "GET /internal/admin_suite renders dashboard" do
      get "/internal/admin_suite"
      assert_response :success
      assert_includes response.body, "Admin Suite"
    end

    test "loads custom root dashboard definition from dashboard_globs" do
      old_globs = AdminSuite.config.dashboard_globs
      old_title = AdminSuite.config.root_dashboard_title
      old_description = AdminSuite.config.root_dashboard_description

      Dir.mktmpdir("admin-suite-dashboard") do |dir|
        dashboard_rb = File.join(dir, "dashboard.rb")

        File.write(dashboard_rb, <<~'RUBY')
          # frozen_string_literal: true

          AdminSuite.configure do |config|
            config.root_dashboard_title = ->(controller) { "Custom Root #{controller.request.path}" }
            config.root_dashboard_description = ->(_controller) { "Custom root description" }
          end

          AdminSuite.root_dashboard do
            row do
              stat_panel "Custom A", -> { 11 }, span: 6, variant: :mini, color: :slate
              stat_panel "Custom B", 22, span: 6, variant: :mini, color: :slate
            end
          end
        RUBY

        AdminSuite.reset_root_dashboard!
        AdminSuite.config.dashboard_globs = [ File.join(dir, "*.rb") ]

        get "/internal/admin_suite"
        assert_response :success

        # Title + description should come from the dashboard definition file.
        assert_includes response.body, "Custom Root /internal/admin_suite"
        assert_includes response.body, "Custom root description"

        # DSL-driven panels should render.
        assert_includes response.body, "Custom A"
        assert_includes response.body, ">11<"
        assert_includes response.body, "Custom B"
        assert_includes response.body, ">22<"

        # Ensure spans are emitted (used to drive column layout).
        assert_includes response.body, "admin-suite-dashboard-row"
        assert_equal 2, response.body.scan("grid-column: span 6 / span 6;").size

        # Loader should mark the dashboard as loaded in non-dev envs (test).
        assert AdminSuite.config.root_dashboard_loaded
        assert AdminSuite.root_dashboard_definition.present?
      end
    ensure
      AdminSuite.config.dashboard_globs = old_globs
      AdminSuite.config.root_dashboard_title = old_title
      AdminSuite.config.root_dashboard_description = old_description
      AdminSuite.reset_root_dashboard!
    end
  end
end
