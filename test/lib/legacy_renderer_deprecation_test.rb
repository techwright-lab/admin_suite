# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class LegacyRendererDeprecationTest < ActionView::TestCase
    include ::ERB::Util
    include AdminSuite::BaseHelper

    Prompt = Struct.new(:prompt_template)

    setup { AdminSuite::Renderers::LegacyGleania.reset_deprecation_notices! }

    test "the legacy prompt renderer still renders its template" do
      html = render_custom_section(Prompt.new("Hello {{name}}"), :prompt_template_preview)
      assert_includes html, "Hello"
      assert_includes html, "name"
    end

    test "using a legacy renderer logs a deprecation once per key" do
      logged = []
      AdminSuite::Renderers::LegacyGleania.stub(:warn_once_sink, ->(msg) { logged << msg }) do
        2.times { render_custom_section(Prompt.new("x"), :prompt_template_preview) }
      end
      assert_equal 1, logged.size
      assert_includes logged.first, "deprecated"
      # Deliberately a hardcoded literal, not read off
      # DEPRECATION_MESSAGE_FORMAT: reading the version out of the constant
      # under test and asserting the message contains it is true by
      # construction (format() only substitutes %<key>s, never the version
      # digits), so it can never fail on a wrong retarget -- exactly the
      # property this test exists to catch. If the removal target changes
      # again, this literal must be updated by hand; that's the point.
      assert_includes logged.first, "0.6.0"
    end

    test "the gem no longer includes the host CustomRenderersHelper constant" do
      source = AdminSuite::Engine.root.join("app/helpers/admin_suite/base_helper.rb").read
      refute_includes source, "Internal::Developer::CustomRenderersHelper"
    end
  end
end
