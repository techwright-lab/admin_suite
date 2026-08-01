# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class NavigationSectionsTest < ActionDispatch::IntegrationTest
    setup do
      AdminSuite::PortalRegistry.reset!
      AdminSuite.portal :ops do
        label "Ops"
        section :zzz_last do
          label "Aaa Displayed First"
          order 1
        end
        section :observability do
          label "Observability"
          order 50
        end
      end
    end

    teardown { AdminSuite::PortalRegistry.reset! }

    test "declared sections use their label and order, not alphabetical keys" do
      get "/internal/admin_suite/ops"
      assert_response :success
      first = response.body.index("Aaa Displayed First")
      second = response.body.index("Observability")
      assert first, "declared section label missing"
      assert second, "second section label missing"
      assert first < second, "sections must honour declared order, not label sort"
    end

    test "undeclared sections still auto-synthesize a humanized label" do
      AdminSuite::PortalRegistry.reset!
      get "/internal/admin_suite/ops"
      assert_response :success
      assert_includes response.body, "Observability" # from ReadOnlyWidgetResource's `section :observability`
    end
  end
end
