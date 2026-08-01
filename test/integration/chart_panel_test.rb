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
        # "[data-admin-suite--chart-target='bars'] > .h-full > div" selector
        # is deliberately anchored under the chart's own card rather than
        # matching against the whole page.
        chart = document.at_xpath("//h3[normalize-space()='From JSONB']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        bar = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div").first
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

    test "a malformed row in an otherwise-good data array degrades instead of a 500" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Mixed", data: -> { [ { label: "ok", value: 3 }, 5, nil ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, "Mixed"
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Mixed']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        # The good row still renders as a full-height bar; the junk rows
        # (an Integer and nil) are silently dropped rather than raising.
        assert_includes chart.text, "ok"
        bars = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div")
        assert_equal 1, bars.size
        assert_equal "height: 100%", bars.first["style"]
      end
    end

    test "chart height defaults to a real chart size and is configurable" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Daily Cost", data: -> { [ { label: "Mon", value: 3 } ] }
            chart_panel "Tall One", data: -> { [ { label: "Mon", value: 3 } ] }, height: 300
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        document = Nokogiri::HTML(response.body)

        default_chart = document.at_xpath("//h3[normalize-space()='Daily Cost']/ancestor::div[contains(@class, 'rounded-xl')]")
        default_bars = default_chart.css("[data-admin-suite--chart-target='bars']").first
        assert_equal "height: 192px;", default_bars["style"]
        assert_includes default_chart.to_s, 'data-admin-suite--chart-height-value="192"'

        tall_chart = document.at_xpath("//h3[normalize-space()='Tall One']/ancestor::div[contains(@class, 'rounded-xl')]")
        tall_bars = tall_chart.css("[data-admin-suite--chart-target='bars']").first
        assert_equal "height: 300px;", tall_bars["style"]
        assert_includes tall_chart.to_s, 'data-admin-suite--chart-height-value="300"'
      end
    end

    test "chart assets load only on pages that render a chart" do
      get "/internal/admin_suite/ops/read_only_widgets"
      assert_response :success
      refute_includes response.body, "vendor/chart"
    end
  end
end
