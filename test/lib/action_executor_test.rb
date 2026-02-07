# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Admin
  module Base
    class ActionExecutorTest < ActiveSupport::TestCase
      setup do
        @temp_dir = Dir.mktmpdir("admin_suite_test")
        @original_config = AdminSuite.config.action_globs.dup
        
        # Reset the handlers_loaded flag before each test
        ActionExecutor.handlers_loaded = false
      end

      teardown do
        FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
        AdminSuite.config.action_globs = @original_config
        
        # Reset the flag after each test
        ActionExecutor.handlers_loaded = false
      end

      test "handlers_loaded flag starts as false" do
        ActionExecutor.handlers_loaded = false
        assert_equal false, ActionExecutor.handlers_loaded
      end

      test "handlers_loaded flag can be set to true" do
        ActionExecutor.handlers_loaded = true
        assert_equal true, ActionExecutor.handlers_loaded
      end

      test "load_action_handlers_for_admin_suite sets handlers_loaded to true after loading" do
        # Create a temporary action handler file
        actions_dir = File.join(@temp_dir, "actions")
        FileUtils.mkdir_p(actions_dir)
        File.write(
          File.join(actions_dir, "test_action.rb"),
          "module Admin\n  module Actions\n    class TestAction\n    end\n  end\nend"
        )

        # Configure AdminSuite to look in our temp directory
        AdminSuite.config.action_globs = [File.join(actions_dir, "*.rb")]

        # Create an executor instance and call the loading method
        resource_class = Struct.new(:resource_name).new("test")
        executor = ActionExecutor.new(resource_class, :test, nil)
        
        # Ensure flag starts as false
        ActionExecutor.handlers_loaded = false
        
        # Call the private method
        executor.send(:load_action_handlers_for_admin_suite!)
        
        # Verify the flag is now true
        assert ActionExecutor.handlers_loaded, "Expected handlers_loaded to be true after loading"
      end

      test "load_action_handlers_for_admin_suite skips loading when handlers_loaded is true" do
        # Create a temporary action handler file
        actions_dir = File.join(@temp_dir, "actions")
        FileUtils.mkdir_p(actions_dir)
        action_file = File.join(actions_dir, "test_action.rb")
        File.write(action_file, "# Test action")

        # Configure AdminSuite to look in our temp directory
        AdminSuite.config.action_globs = [File.join(actions_dir, "*.rb")]

        # Create an executor instance
        resource_class = Struct.new(:resource_name).new("test")
        executor = ActionExecutor.new(resource_class, :test, nil)

        # Set the flag to true to simulate already loaded
        ActionExecutor.handlers_loaded = true

        # Mock Dir[] to verify it's not called
        glob_called = false
        original_bracket = Dir.method(:[])
        Dir.define_singleton_method(:[]) do |pattern|
          glob_called = true
          original_bracket.call(pattern)
        end

        begin
          # Call the loading method
          executor.send(:load_action_handlers_for_admin_suite!)

          # Verify glob was not called because handlers were already loaded
          assert_not glob_called, "Expected Dir[] to not be called when handlers_loaded is true"
        ensure
          # Restore Dir.[] method
          Dir.define_singleton_method(:[], original_bracket)
        end
      end

      test "load_action_handlers_for_admin_suite returns early when AdminSuite is not defined" do
        # Temporarily undefine AdminSuite to test early return
        admin_suite_defined = defined?(AdminSuite)
        
        skip "Cannot test AdminSuite undefined condition when AdminSuite is required" if admin_suite_defined

        resource_class = Struct.new(:resource_name).new("test")
        executor = ActionExecutor.new(resource_class, :test, nil)
        
        # This should return early without error
        assert_nil executor.send(:load_action_handlers_for_admin_suite!)
      end

      test "load_action_handlers_for_admin_suite handles empty action_globs gracefully" do
        # Set action_globs to empty
        AdminSuite.config.action_globs = []

        resource_class = Struct.new(:resource_name).new("test")
        executor = ActionExecutor.new(resource_class, :test, nil)
        
        ActionExecutor.handlers_loaded = false

        # This should not raise an error
        assert_nothing_raised do
          executor.send(:load_action_handlers_for_admin_suite!)
        end

        # Flag should be set even when no files exist to avoid repeated expensive globs
        assert ActionExecutor.handlers_loaded, "Expected handlers_loaded to be true even when no files exist"
      end

      test "load_action_handlers_for_admin_suite handles errors gracefully" do
        # Configure a glob pattern that will cause an error
        AdminSuite.config.action_globs = ["/nonexistent/path/*.rb"]

        resource_class = Struct.new(:resource_name).new("test")
        executor = ActionExecutor.new(resource_class, :test, nil)
        
        ActionExecutor.handlers_loaded = false

        # This should not raise an error even if globbing fails
        assert_nothing_raised do
          executor.send(:load_action_handlers_for_admin_suite!)
        end
      end
    end
  end
end
