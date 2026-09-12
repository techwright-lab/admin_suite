# frozen_string_literal: true

require "test_helper"

class RemovedDeprecationsTest < ActiveSupport::TestCase
  test "the gem has no legacy Gleania renderer implementations or defaults" do
    refute defined?(AdminSuite::Renderers::LegacyGleania)
    %i[prompt_template_preview messages_preview tool_args_preview turn_messages_preview].each do |key|
      assert_nil AdminSuite::RendererRegistry.lookup_default(key)
    end
  end

  test "exportable is no longer a resource DSL method" do
    refute Admin::Base::Resource.respond_to?(:exportable)
  end
end
