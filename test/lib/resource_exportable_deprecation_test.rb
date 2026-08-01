# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class ResourceExportableDeprecationTest < ActiveSupport::TestCase
    # Regression fixture for Finding 1 of the whole-branch review: Task 8
    # removed `exportable` after grepping the *gem* for readers, but host
    # apps are *callers* of this DSL (gleania: 30 resource files;
    # trust_growth: 1). A real removal raises `NoMethodError` at
    # definition-load time -- and in production `DefinitionLoader` logs and
    # swallows that, so the resource silently vanishes from the admin.
    class LegacyExportableResource < Admin::Base::Resource
      exportable :json, :csv
    end

    setup { LegacyExportableResource.reset_deprecation_notices! }

    test "calling exportable in a resource body is harmless" do
      assert_nothing_raised { LegacyExportableResource.exportable(:json, :csv) }
    end

    test "exportable does not restore any export-format reader" do
      refute LegacyExportableResource.respond_to?(:export_formats)
      refute LegacyExportableResource.instance_variable_defined?(:@export_formats)
    end

    test "exportable warns once per resource class, naming the class and the 0.5.0 removal" do
      logged = []
      LegacyExportableResource.stub(:warn_once_sink, ->(msg) { logged << msg }) do
        2.times { LegacyExportableResource.exportable(:json, :csv) }
      end

      assert_equal 1, logged.size
      assert_includes logged.first, "LegacyExportableResource"
      assert_includes logged.first, "0.5.0"
    end
  end
end
