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

    test "a Hash row with a non-numeric value degrades to a zero-height bar instead of a 500" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Junk Values", data: -> {
              [
                { label: "bool", value: true },
                { label: "hash", value: {} },
                { label: "array", value: [ 1, 2 ] },
                { label: "good", value: 5 }
              ]
            }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, "Junk Values"
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Junk Values']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        # Boolean/Hash/Array values used to raise via #to_f (e.g. `true.to_f`
        # is a NoMethodError). They now coerce to 0 instead of 500ing, and
        # the one well-formed row alongside them still renders at full height.
        bars = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div")
        assert_equal 4, bars.size
        assert_equal [ "height: 0%", "height: 0%", "height: 0%", "height: 100%" ], bars.map { |bar| bar["style"] }
        assert_includes chart.text, "good"
      end
    end

    test "a numeric-string value still displays without a trailing .0 in the tooltip" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "String Value", data: -> { [ { label: "Str", value: "3" } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='String Value']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        bar = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div").first
        assert bar, "expected a rendered bar"
        # Display keeps the original value ("3"), even though the height math
        # underneath uses the coerced numeric (3.0) — no display regression
        # from the total-coercion fix.
        assert_equal "Str: 3", bar["title"]
        assert_equal "height: 100%", bar["style"]
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

    # Final review Finding 1: `chart_height.presence || 192` lets any value
    # that survives `presence` (true, Symbols, non-empty Arrays/Hashes)
    # through to `#to_i`, which none of those implement -- NoMethodError,
    # 500ing the whole dashboard. Regression tests for the total-coercion fix
    # (`Integer(Float(...))` rescuing ArgumentError/TypeError), mirroring the
    # `type:` junk-value tests above.
    #
    # The Float::INFINITY/NAN cases come from the fix's own re-review: those
    # parse as Floats but have no Integer form, so `Integer()` raises
    # FloatDomainError -- a RangeError, which the first cut of the rescue did
    # not name. They were the one junk value still 500ing the dashboard, and a
    # host reaches them by computing a height from a ratio that divides by zero.
    [ "true", ":tall", "[200]", "{ px: 200 }", '"abc"', "nil", "0", "-5",
      "Float::INFINITY", "-Float::INFINITY", "Float::NAN" ].each do |literal|
      test "height: #{literal} does not raise and falls back to the default 192px" do
        with_dashboard(<<~RUBY) do
          AdminSuite.root_dashboard do
            row do
              chart_panel "Junk Height", height: #{literal}, data: -> { [ { label: "Mon", value: 3 } ] }
            end
          end
        RUBY
          get "/internal/admin_suite"
          assert_response :success
          document = Nokogiri::HTML(response.body)
          chart = document.at_xpath("//h3[normalize-space()='Junk Height']/ancestor::div[contains(@class, 'rounded-xl')]")
          assert chart, "expected the chart panel card"
          bars = chart.css("[data-admin-suite--chart-target='bars']").first
          assert_equal "height: 192px;", bars["style"]
          assert_includes chart.to_s, 'data-admin-suite--chart-height-value="192"'
        end
      end
    end

    [ [ '"240"', "240" ], [ "240.7", "240" ] ].each do |literal, expected|
      test "height: #{literal} is coerced to a real pixel height instead of the default" do
        with_dashboard(<<~RUBY) do
          AdminSuite.root_dashboard do
            row do
              chart_panel "Parsed Height", height: #{literal}, data: -> { [ { label: "Mon", value: 3 } ] }
            end
          end
        RUBY
          get "/internal/admin_suite"
          assert_response :success
          document = Nokogiri::HTML(response.body)
          chart = document.at_xpath("//h3[normalize-space()='Parsed Height']/ancestor::div[contains(@class, 'rounded-xl')]")
          assert chart, "expected the chart panel card"
          bars = chart.css("[data-admin-suite--chart-target='bars']").first
          assert_equal "height: #{expected}px;", bars["style"]
          assert_includes chart.to_s, %(data-admin-suite--chart-height-value="#{expected}")
        end
      end
    end

    # Final review Finding 2: `(panel.options[:color] || theme_primary).to_sym`
    # raises `NoMethodError` for any `color:` value that doesn't implement
    # `#to_sym` (e.g. an Integer or Boolean). Pre-existing since 0.4.0.
    # Regression tests for the `.to_s.presence&.to_sym` fix -- unknown colors
    # already fall through to indigo in both the ERB `case` and the JS
    # `COLOR_HEX` map, so an unrecognized coerced value is expected to render
    # the indigo bar, not raise.
    test "a non-Symbol, non-String color: (an Integer) falls back to indigo instead of raising" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Integer Color", color: 42, data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Integer Color']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        assert_includes chart.to_s, 'data-admin-suite--chart-color-value="42"'
        bar = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div").first
        assert_includes bar["class"], "bg-indigo-500"
      end
    end

    test "a Boolean color: (true) falls back to indigo instead of raising" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Boolean Color", color: true, data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Boolean Color']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        assert_includes chart.to_s, 'data-admin-suite--chart-color-value="true"'
        bar = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div").first
        assert_includes bar["class"], "bg-indigo-500"
      end
    end

    test "a known color: as a Symbol still renders its matching bar color" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Amber Color", color: :amber, data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Amber Color']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        assert_includes chart.to_s, 'data-admin-suite--chart-color-value="amber"'
        bar = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div").first
        assert_includes bar["class"], "bg-amber-500"
      end
    end

    test "chart assets load only on pages that render a chart" do
      # Self-contained via `with_dashboard` (defined above in this file)
      # rather than hitting a fixture route registered by a *different* test
      # file (`/ops/read_only_widgets`, from read_only_resource_test.rb):
      # that made this test pass in the full suite but 404 under
      # `TEST=test/integration/chart_panel_test.rb` isolation, since that
      # other file's resource/route never gets registered. A `stat_panel`
      # renders no chart at all, so this is guaranteed chart-free regardless
      # of what else has (or hasn't) been loaded.
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            stat_panel "Active Users", 42
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        refute_includes response.body, "vendor/chart"
      end
    end

    test "chart_panel with no type: still renders exactly as a bar chart" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Bar Default", data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, 'data-admin-suite--chart-type-value="bar"'
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Bar Default']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        bars = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div")
        assert_equal 1, bars.size
      end
    end

    test "chart_panel type: :line serializes to the DOM and degrades to CSS bars" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Line Chart", type: :line, data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, 'data-admin-suite--chart-type-value="line"'
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Line Chart']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        # line's degraded (no-JS) rendering is the same CSS bars as bar/area —
        # a line chart with one data point has no sensible line-only degrade.
        bars = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div")
        assert_equal 1, bars.size
      end
    end

    test "chart_panel type: :area serializes to the DOM and degrades to CSS bars" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Area Chart", type: :area, data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, 'data-admin-suite--chart-type-value="area"'
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Area Chart']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        bars = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div")
        assert_equal 1, bars.size
      end
    end

    test "chart_panel type: :doughnut serializes to the DOM and degrades to a labelled value list, not bars" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Doughnut Chart", type: :doughnut, data: -> {
              [ { label: "Mon", value: 3 }, { label: "Tue", value: 7 } ]
            }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, 'data-admin-suite--chart-type-value="doughnut"'
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Doughnut Chart']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        # A stacked bar makes no sense for a doughnut's degraded state — assert
        # there are no percentage-height bars, and instead a plain label/value
        # list carries both rows' data.
        assert_empty chart.css("[data-admin-suite--chart-target='bars']")
        assert_includes chart.text, "Mon"
        assert_includes chart.text, "3"
        assert_includes chart.text, "Tue"
        assert_includes chart.text, "7"
      end
    end

    test "an unknown chart type falls back to :bar and does not raise" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Weird Chart", type: :bogus, data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, 'data-admin-suite--chart-type-value="bar"'
        refute_includes response.body, 'data-admin-suite--chart-type-value="bogus"'
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Weird Chart']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        bars = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div")
        assert_equal 1, bars.size
      end
    end

    test "a non-Symbol, non-String type: (an Integer) falls back to :bar instead of raising" do
      # `type: 42` used to reach `.presence&.to_sym` directly -- `presence`
      # passes an Integer through unchanged, and Integer has no `#to_sym`,
      # so this 500ed the whole dashboard rather than degrading. Regression
      # test for that total-coercion fix.
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Integer Type", type: 42, data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, 'data-admin-suite--chart-type-value="bar"'
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Integer Type']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        bars = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div")
        assert_equal 1, bars.size
      end
    end

    test "a Boolean type: (true) falls back to :bar instead of raising" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "Boolean Type", type: true, data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, 'data-admin-suite--chart-type-value="bar"'
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='Boolean Type']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        bars = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div")
        assert_equal 1, bars.size
      end
    end

    test "a valid type: given as a String (not a Symbol) is honored, not just tolerated" do
      with_dashboard(<<~RUBY) do
        AdminSuite.root_dashboard do
          row do
            chart_panel "String Type", type: "line", data: -> { [ { label: "Mon", value: 3 } ] }
          end
        end
      RUBY
        get "/internal/admin_suite"
        assert_response :success
        assert_includes response.body, 'data-admin-suite--chart-type-value="line"'
        document = Nokogiri::HTML(response.body)
        chart = document.at_xpath("//h3[normalize-space()='String Type']/ancestor::div[contains(@class, 'rounded-xl')]")
        assert chart, "expected the chart panel card"
        # "line" still degrades to CSS bars, same as the Symbol form.
        bars = chart.css("[data-admin-suite--chart-target='bars'] > .h-full > div")
        assert_equal 1, bars.size
      end
    end
  end
end
