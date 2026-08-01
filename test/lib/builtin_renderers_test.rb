# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class BuiltinRenderersTest < ActionView::TestCase
    include ::ERB::Util
    include AdminSuite::BaseHelper

    Record = Struct.new(:id, :config, :rows, :snippet) do
      def attributes = { "id" => id }
    end

    def record
      Record.new(
        3,
        { "mode" => "fast" },
        [ { name: "alpha", count: 2 }, { name: "beta", count: 5 } ],
        "puts :hi"
      )
    end

    def build(key, **options)
      AdminSuite::RendererRegistry.lookup(key).new(record, self, options).render
    end

    test "json renderer prints the source hash" do
      assert_includes build(:json, source: ->(r) { r.config }), "mode"
    end

    test "json renderer defaults to record attributes" do
      # json_block HTML-escapes the pretty-printed JSON (see
      # RendererTest#"json_block renders pretty-printed JSON..." for the
      # same &quot; pattern), so a literal `"id"` never appears verbatim.
      assert_includes build(:json), "&quot;id&quot;"
    end

    test "key_value renderer renders each pair" do
      # KeyValueRenderer humanizes keys (`k.to_s.humanize`), so "mode"
      # renders as "Mode".
      html = build(:key_value, source: ->(r) { r.config })
      assert_includes html, "Mode"
      assert_includes html, "fast"
    end

    test "table_from renderer renders rows and infers columns" do
      html = build(:table_from, source: ->(r) { r.rows })
      assert_includes html, "alpha"
      assert_includes html, "beta"
      assert_includes html, "Count"
    end

    test "table_from renderer honours explicit columns and empty message" do
      html = build(:table_from, source: ->(_r) { [] }, columns: %i[name], empty: "no data")
      assert_includes html, "no data"
    end

    test "code renderer renders the snippet" do
      assert_includes build(:code, source: ->(r) { r.snippet }, language: :ruby), "puts"
    end

    test "a symbol source resolves a method on the record" do
      assert_includes build(:json, source: :config), "mode"
    end

    test "json_preview and code_preview are registered aliases to the same classes" do
      assert_equal AdminSuite::Renderers::JsonRenderer, AdminSuite::RendererRegistry.lookup(:json_preview)
      assert_equal AdminSuite::Renderers::CodeRenderer, AdminSuite::RendererRegistry.lookup(:code_preview)
    end

    test "key_value renderer shows an empty state for a blank source" do
      html = build(:key_value, source: ->(_r) { {} })
      assert_includes html, "Nothing to display."
    end

    test "table_from renderer's :columns option reaches the renderer through render_custom_section" do
      section = Admin::Base::Resource::ShowSectionDefinition.new(
        name: :costs,
        render: :table_from,
        options: { source: ->(r) { r.rows }, columns: %i[name] }
      )

      html = render_custom_section(record, section.render, section.options)

      assert_includes html, "alpha"
      refute_includes html, "Count"
    end

    # Full DSL path: a host resource's `show { panel ... }` block, through
    # ShowConfig#build_section, to render_show_section, to render_custom_section,
    # to the registered renderer. No prior test in this suite exercised
    # build_section at all, so this pins the plumbing this task added:
    # ShowSectionDefinition#options is populated from the panel's leftover
    # DSL keys (source:, columns:, empty:), including `columns:` a second
    # time even though it also has its own dedicated `section.columns` slot.
    class DslProbeResource < Admin::Base::Resource
      show do
        panel :costs, title: "Provider Costs",
          render: :table_from,
          source: ->(r) { r.rows },
          columns: %i[name],
          empty: "No spend"
      end
    end

    test "panel DSL options reach the renderer end-to-end" do
      section = DslProbeResource.show_config.sections_list.find { |s| s.name == :costs }

      assert_equal :table_from, section.render
      assert_equal %i[name], section.columns
      assert_equal({ source: section.options[:source], columns: %i[name], empty: "No spend" }, section.options)

      html = render_show_section(record, section, :main)

      assert_includes html, "alpha"
      assert_includes html, "beta"
      refute_includes html, "Count"
    end
  end
end
