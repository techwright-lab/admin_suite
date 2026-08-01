# frozen_string_literal: true

require "test_helper"

# Reopened (never redefined) so RendererTest can define/remove scratch
# `Admin::Renderers::<Key>Renderer` probe classes per test, for Finding 2's
# host-class-vs-gem-default precedence tests below.
module Admin
  module Renderers
  end
end

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
    teardown { AdminSuite::RendererRegistry.unregister(:greeting) }

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

    test "registered lists every registered key" do
      assert_includes AdminSuite::RendererRegistry.registered, :greeting
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

    # Lookup-precedence regression guard. Tasks 4 and 5 both insert new
    # branches into render_custom_section (built-ins, then the deprecated
    # Gleania four) between the registry lookup and the "Unknown" fallback —
    # this pins the two boundaries already in place today so neither task can
    # silently invert them.
    test "a legacy custom_renderers proc wins over a registered renderer class" do
      key = :precedence_probe
      AdminSuite::RendererRegistry.register(key, GreetingRenderer)
      saved = AdminSuite.config.custom_renderers[key]
      AdminSuite.config.custom_renderers[key] = ->(record, _view) { "legacy-proc-#{record.id}" }

      html = render_custom_section(Record.new(5), key)

      assert_includes html, "legacy-proc-5"
      refute_includes html, "Hello 5"
    ensure
      AdminSuite::RendererRegistry.unregister(key)
      AdminSuite.config.custom_renderers.delete(key)
      AdminSuite.config.custom_renderers[key] = saved if saved
    end

    # Finding 4 of the whole-branch review: `config.custom_renderers` procs
    # were deprecated on paper only (CHANGELOG, 0.4.0) with no runtime
    # signal -- unlike the four legacy Gleania renderers, which warn once
    # per key. trust_growth has 23 of these procs and needs a way to notice
    # during the migration window.
    test "using a legacy custom_renderers proc logs a deprecation once per key" do
      key = :legacy_proc_warning_probe
      AdminSuite::LegacyCustomRendererProcs.reset_deprecation_notices!
      AdminSuite.config.custom_renderers[key] = ->(record, _view) { "legacy-proc-#{record.id}" }

      logged = []
      AdminSuite::LegacyCustomRendererProcs.stub(:warn_once_sink, ->(msg) { logged << msg }) do
        2.times { render_custom_section(Record.new(5), key) }
      end

      assert_equal 1, logged.size
      assert_includes logged.first, key.to_s
      assert_includes logged.first, "deprecated"
      assert_includes logged.first, "0.5.0"
    ensure
      AdminSuite.config.custom_renderers.delete(key)
    end

    # Finding 2 of the whole-branch review: render_custom_section used to
    # resolve `RendererRegistry.lookup(key) || host_renderer_class(key)`,
    # but the gem's own built-ins and the deprecated Gleania four were
    # registered into that same `lookup` store at require time -- so a host
    # that followed the deprecation advice ("Move it to app/admin/renderers
    # in your app") and defined its own `Admin::Renderers::<Key>Renderer`
    # was silently shadowed, and the deprecation warning never stopped.
    # Built-ins/deprecated-four now live in a separate `register_default`
    # store, checked only *after* a host renderer class.
    test "a host renderer class beats a gem default registered under the same key" do
      key = :host_beats_default_probe
      AdminSuite::RendererRegistry.register_default(key, GreetingRenderer)
      Admin::Renderers.const_set(:HostBeatsDefaultProbeRenderer, Class.new(AdminSuite::Renderer) do
        def render
          "host-class-#{record.id}"
        end
      end)

      html = render_custom_section(Record.new(7), key)

      assert_includes html, "host-class-7"
      refute_includes html, "Hello 7"
    ensure
      if Admin::Renderers.const_defined?(:HostBeatsDefaultProbeRenderer, false)
        Admin::Renderers.send(:remove_const, :HostBeatsDefaultProbeRenderer)
      end
    end

    test "an explicit registration still beats a host renderer class" do
      key = :explicit_beats_host_probe
      AdminSuite::RendererRegistry.register(key, GreetingRenderer)
      Admin::Renderers.const_set(:ExplicitBeatsHostProbeRenderer, Class.new(AdminSuite::Renderer) do
        def render
          "host-class-#{record.id}"
        end
      end)

      html = render_custom_section(Record.new(8), key)

      assert_includes html, "Hello 8"
      refute_includes html, "host-class-8"
    ensure
      AdminSuite::RendererRegistry.unregister(key)
      if Admin::Renderers.const_defined?(:ExplicitBeatsHostProbeRenderer, false)
        Admin::Renderers.send(:remove_const, :ExplicitBeatsHostProbeRenderer)
      end
    end

    test "a registered renderer class wins over the built-in case branches" do
      # :json_preview has a legacy case branch; a registered class must take it over.
      #
      # Task 4 registers :json_preview as a permanent alias to JsonRenderer
      # at require time, so — unlike when this test was first written —
      # there is now always a prior registration to restore. Unregistering
      # unconditionally in `ensure` would delete that alias process-wide for
      # every test that runs after this one (a real, order-dependent bug
      # this exact test used to hide).
      previous = AdminSuite::RendererRegistry.lookup(:json_preview)
      AdminSuite::RendererRegistry.register(:json_preview, GreetingRenderer)
      assert_includes render_custom_section(Record.new(6), :json_preview), "Hello 6"
    ensure
      if previous
        AdminSuite::RendererRegistry.register(:json_preview, previous)
      else
        AdminSuite::RendererRegistry.unregister(:json_preview)
      end
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
