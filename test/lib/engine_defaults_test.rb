# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class EngineDefaultsTest < ActiveSupport::TestCase
    def with_fresh_config
      saved = AdminSuite.instance_variable_get(:@config)
      AdminSuite.instance_variable_set(:@config, AdminSuite::Configuration.new)
      yield AdminSuite.config
    ensure
      AdminSuite.instance_variable_set(:@config, saved)
    end

    test "an explicit empty portals hash suppresses the built-in defaults" do
      with_fresh_config do |config|
        config.portals = {}
        assert config.portals_configured?, "assigning portals must mark them configured"
        AdminSuite::Engine.apply_default_portals!(config)
        assert_empty config.portals
      end
    end

    test "untouched portals receive the built-in defaults" do
      with_fresh_config do |config|
        refute config.portals_configured?
        AdminSuite::Engine.apply_default_portals!(config)
        assert_includes config.portals.keys, :ops
      end
    end

    test "dead configuration and DSL members are gone" do
      refute AdminSuite::Configuration.new.respond_to?(:tailwind_cdn)
      refute Admin::Base::Resource.respond_to?(:exportable)
      refute Admin::Base::Resource::ColumnDefinition.members.include?(:render)
    end
  end
end
