# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class RendererTest < ActionView::TestCase
    # See ShowValueFormatterTest for why this is needed: BaseHelper's
    # primitives (via render_json_block / render_text_block) call bare `h`,
    # which ActionView::TestCase::Behavior does not provide on its own.
    include ::ERB::Util
    include AdminSuite::BaseHelper

    Record = Struct.new(:id, :payload)

    class GreetingRenderer < AdminSuite::Renderer
      def render
        content_tag(:p, "Hello #{record.id}")
      end
    end

    class PrimitivesRenderer < AdminSuite::Renderer
      def render
        safe_join([
          key_value_list([ [ "Status", "active" ] ]),
          data_table([ { name: "a", count: 1 } ], columns: %i[name count]),
          badge("live", color: :green),
          empty_state("nothing here")
        ])
      end
    end

    setup { AdminSuite::RendererRegistry.register(:greeting, GreetingRenderer) }

    test "a renderer subclass receives the record and renders" do
      assert_includes GreetingRenderer.new(Record.new(7), self).render, "Hello 7"
    end

    test "the base class requires #render" do
      assert_raises(NotImplementedError) { AdminSuite::Renderer.new(Record.new(1), self).render }
    end

    test "registry lookup returns the registered class and raises for unknown keys" do
      assert_equal GreetingRenderer, AdminSuite::RendererRegistry.lookup(:greeting)
      assert_nil AdminSuite::RendererRegistry.lookup(:nope)
    end

    test "primitives render key-value pairs, tables, badges and empty states" do
      html = PrimitivesRenderer.new(Record.new(1), self).render
      assert_includes html, "Status"
      assert_includes html, "active"
      # data_table humanizes column names for the header (see Renderer#data_table),
      # so ":count" renders as "Count", not "count".
      assert_includes html, "Count"
      assert_includes html, "live"
      assert_includes html, "nothing here"
    end

    test "data_table renders its empty message when rows are blank" do
      html = AdminSuite::Renderer.new(Record.new(1), self).send(:data_table, [], columns: %i[a], empty: "no rows")
      assert_includes html, "no rows"
    end

    test "render_custom_section resolves a registered renderer class" do
      assert_includes render_custom_section(Record.new(9), :greeting), "Hello 9"
    end

    # json_block/code_block/badge each delegate to a BaseHelper primitive whose
    # real signature differs from the brief's illustrative sketch
    # (render_json_block takes no `title:`; render_label_badge takes `color:`
    # as a keyword, not positional) — these primitives were adapted to match,
    # per the task's explicit instruction. Covered directly since the brief's
    # own PrimitivesRenderer test never exercises json_block or code_block.
    test "json_block renders pretty-printed JSON, with an optional title heading" do
      renderer = AdminSuite::Renderer.new(Record.new(1), self)
      html = renderer.send(:json_block, { a: 1 })
      assert_includes html, "language-json"
      assert_includes html, "&quot;a&quot;"

      titled = renderer.send(:json_block, { a: 1 }, title: "Payload")
      assert_includes titled, "Payload"
      assert_includes titled, "language-json"
    end

    test "code_block renders a syntax-highlighted text block" do
      html = AdminSuite::Renderer.new(Record.new(1), self).send(:code_block, "SELECT 1", language: :sql)
      assert_includes html, "SELECT 1"
      assert_includes html, "language-sql"
    end

    test "badge renders the label with its color class, passed as a keyword" do
      html = AdminSuite::Renderer.new(Record.new(1), self).send(:badge, "live", color: :green)
      assert_includes html, "live"
      assert_includes html, "bg-green-100"
    end
  end
end
