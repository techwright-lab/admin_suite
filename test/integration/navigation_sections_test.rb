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

    # `:zzz_last` (declared in `setup` above) has no resources registered
    # under it anywhere in the suite, unlike `:observability`. Before this
    # fix, `_sidebar.html.erb` rendered a bare section label with nothing
    # underneath for a section like this; `portals/show.html.erb` already
    # showed "No resources in this section yet." for the same case, so the
    # sidebar was the odd one out.
    test "the sidebar shows the no-resources message for a declared but empty section" do
      get "/internal/admin_suite/ops"
      assert_response :success

      # Scoped to the sidebar itself: `portals/show.html.erb`'s own fallback
      # section list also renders "No resources in this section yet." for
      # the same empty section, so an unscoped `assert_includes` on the full
      # body wouldn't actually prove the *sidebar* (as opposed to the main
      # content) says it.
      sidebar = Nokogiri::HTML(response.body).at_css(".admin-suite-sidebar")
      assert sidebar, "expected to find the sidebar"
      assert_includes sidebar.text, "Aaa Displayed First"
      assert_includes sidebar.text, "No resources in this section yet."
    end
  end
end
