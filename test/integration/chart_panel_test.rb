# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module AdminSuite
  class ChartPanelTest < ActionDispatch::IntegrationTest
    # Renders a root dashboard from a temp file. Mirrors the recipe in
    # dashboard_test.rb, which is the only reliable way to exercise panels.
    def with_dashboard(body)
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "dashboard.rb"), body)
        saved = AdminSuite.config.dashboard_globs
        AdminSuite.config.dashboard_globs = [ File.join(dir, "*.rb") ]
        AdminSuite.reset_root_dashboard!
        AdminSuite::DefinitionLoader.reset!(:dashboards)
        yield
      ensure
        AdminSuite.config.dashboard_globs = saved
        AdminSuite.reset_root_dashboard!
        AdminSuite::DefinitionLoader.reset!(:dashboards)
      end
    end

    test "a chart panel emits the chart controller with serialized series" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Daily Cost", data: -> { [ { label: "Mon", value: 3 }, { label: "Tue", value: 7 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, "admin-suite--chart"
        assert_includes response.body, "Mon"
        assert_includes response.body, "Tue"
      end
    end

    test "string-keyed chart data renders values, not blank bars" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "From JSONB", data: -> { [ { "label" => "Alpha", "value" => 5 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, "Alpha"
        document = Nokogiri::HTML(response.body)
        # Scoped to the chart's own card: the layout's topbar partial also has
        # h-16/h-full classes (unrelated to the chart), so an unscoped
        # ".h-16 > .h-full > div" selector matches that markup first.
        chart = document.at_xpath("//h3[normalize-space()='From JSONB']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        bar = chart.css(".h-16 > .h-full > div").first
        assert bar, "expected a rendered bar"
        assert_equal "height: 100%", bar["style"], "string-keyed value must normalize like a symbol-keyed one"
      end
    end

    test "a raising data proc degrades to the empty state instead of a 500" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Broken", data: -> { raise "boom" }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, "Broken"
      end
    end

    test "chart assets load only on pages that render a chart" do
      get "/internal/admin_suite/ops/read_only_widgets"
      assert_response :success
      refute_includes response.body, "vendor/chart"
    end
  end
end
