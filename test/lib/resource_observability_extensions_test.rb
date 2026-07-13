# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class ResourceObservabilityExtensionsTest < ActiveSupport::TestCase
    FakeScope = Struct.new(:filters) do
      def where(*arguments)
        self.class.new(filters + [ arguments ])
      end
    end

    class FilteredResource < Admin::Base::Resource
      index do
        filters do
          filter :window, type: :select, default: "24h",
            apply: ->(scope, value) { scope.where(window: value) }
          filter :status, type: :select
        end
      end
    end

    class ReadOnlyResource < Admin::Base::Resource
      read_only
    end

    test "resources are writable by default and may be declared read only" do
      refute Admin::Base::Resource.read_only?
      assert ReadOnlyResource.read_only?
    end

    test "filter defaults apply when the parameter is absent" do
      scope = Admin::Base::FilterBuilder.new(FilteredResource, ActionController::Parameters.new)
        .apply(FakeScope.new([]))

      assert_equal [ [ { window: "24h" } ] ], scope.filters
    end

    test "filter defaults apply when the parameter is blank and compose with explicit filters" do
      params = ActionController::Parameters.new(window: "", status: "failed")
      scope = Admin::Base::FilterBuilder.new(FilteredResource, params).apply(FakeScope.new([]))

      assert_equal [ [ { window: "24h" } ], [ { status: "failed" } ] ], scope.filters
    end

    test "an explicit filter overrides its default" do
      params = ActionController::Parameters.new(window: "7d")
      scope = Admin::Base::FilterBuilder.new(FilteredResource, params).apply(FakeScope.new([]))

      assert_equal [ [ { window: "7d" } ] ], scope.filters
    end
  end
end
