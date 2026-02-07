# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class ZeitwerkIntegrationTest < ActiveSupport::TestCase
    setup do
      @temp_dir = Dir.mktmpdir("admin_suite_test")
    end

    teardown do
      FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    end

    # Helper method to create a loader that tracks ignored directories
    def create_tracked_loader
      loader = Zeitwerk::Loader.new
      ignored_dirs = []

      loader.define_singleton_method(:ignore) do |path|
        ignored_dirs << path.to_s
      end

      [loader, ignored_dirs]
    end

    # Helper method that simulates the Zeitwerk integration logic from engine.rb
    def simulate_zeitwerk_integration(app_root, loader)
      host_dsl_dirs = [app_root.join("app/admin_suite")]
      host_admin_portals_dir = app_root.join("app/admin/portals")

      if host_admin_portals_dir.exist?
        portal_files = Dir[host_admin_portals_dir.join("**/*.rb").to_s]
        contains_admin_suite_portals =
          portal_files.any? do |file|
            content = File.binread(file).encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
            content.include?("AdminSuite.portal")
          rescue StandardError
            false
          end

        host_dsl_dirs << host_admin_portals_dir if contains_admin_suite_portals
      end

      host_dsl_dirs.each do |dir|
        loader.ignore(dir) if dir.exist?
      end
    end

    test "ignores app/admin/portals when it contains AdminSuite portal DSL" do
      # Create app/admin/portals directory with portal DSL file
      portals_dir = File.join(@temp_dir, "app", "admin", "portals")
      FileUtils.mkdir_p(portals_dir)
      File.write(
        File.join(portals_dir, "ops_portal.rb"),
        "AdminSuite.portal :ops do\n  # portal config\nend"
      )

      # Create loader and simulate initializer logic
      app_root = Pathname.new(@temp_dir)
      loader, ignored_dirs = create_tracked_loader
      simulate_zeitwerk_integration(app_root, loader)

      # Verify that app/admin/portals was ignored
      expected_path = app_root.join("app/admin/portals").to_s
      assert_includes ignored_dirs, expected_path,
                      "Expected app/admin/portals to be ignored when it contains AdminSuite portal DSL"
    end

    test "does not ignore app/admin/portals when it contains only real constants" do
      # Create app/admin/portals directory with a real constant definition
      portals_dir = File.join(@temp_dir, "app", "admin", "portals")
      FileUtils.mkdir_p(portals_dir)
      File.write(
        File.join(portals_dir, "admin_user.rb"),
        "module Admin\n  module Portals\n    class AdminUser\n    end\n  end\nend"
      )

      # Create loader and simulate initializer logic
      app_root = Pathname.new(@temp_dir)
      loader, ignored_dirs = create_tracked_loader
      simulate_zeitwerk_integration(app_root, loader)

      # Verify that app/admin/portals was NOT ignored
      unexpected_path = app_root.join("app/admin/portals").to_s
      assert_not_includes ignored_dirs, unexpected_path,
                          "Expected app/admin/portals to NOT be ignored when it contains only real constants"
    end

    test "always ignores app/admin_suite directory when it exists" do
      # Create app/admin_suite directory
      admin_suite_dir = File.join(@temp_dir, "app", "admin_suite")
      FileUtils.mkdir_p(admin_suite_dir)
      File.write(
        File.join(admin_suite_dir, "some_config.rb"),
        "# Some DSL configuration"
      )

      # Create loader and simulate initializer logic
      app_root = Pathname.new(@temp_dir)
      loader, ignored_dirs = create_tracked_loader
      simulate_zeitwerk_integration(app_root, loader)

      # Verify that app/admin_suite was ignored
      expected_path = app_root.join("app/admin_suite").to_s
      assert_includes ignored_dirs, expected_path,
                      "Expected app/admin_suite to always be ignored"
    end

    test "handles mixed content - ignores app/admin/portals if any file contains portal DSL" do
      # Create app/admin/portals directory with both real constants and portal DSL
      portals_dir = File.join(@temp_dir, "app", "admin", "portals")
      FileUtils.mkdir_p(portals_dir)

      # File with real constant
      File.write(
        File.join(portals_dir, "admin_user.rb"),
        "module Admin\n  module Portals\n    class AdminUser\n    end\n  end\nend"
      )

      # File with portal DSL
      File.write(
        File.join(portals_dir, "ops_portal.rb"),
        "AdminSuite.portal :ops do\n  # portal config\nend"
      )

      # Create loader and simulate initializer logic
      app_root = Pathname.new(@temp_dir)
      loader, ignored_dirs = create_tracked_loader
      simulate_zeitwerk_integration(app_root, loader)

      # Verify that app/admin/portals was ignored due to presence of portal DSL
      expected_path = app_root.join("app/admin/portals").to_s
      assert_includes ignored_dirs, expected_path,
                      "Expected app/admin/portals to be ignored when any file contains portal DSL"
    end

    test "handles file read errors gracefully" do
      # Create app/admin/portals directory with a file
      portals_dir = File.join(@temp_dir, "app", "admin", "portals")
      FileUtils.mkdir_p(portals_dir)
      test_file = File.join(portals_dir, "test.rb")
      File.write(test_file, "AdminSuite.portal :ops do; end")

      # Create loader
      app_root = Pathname.new(@temp_dir)
      loader, ignored_dirs = create_tracked_loader

      # Capture original binread method before stubbing
      original_binread = File.method(:binread)

      # Stub File.binread to raise an error using Minitest's stub method
      stub_binread = lambda do |path|
        if path == test_file
          raise StandardError, "Simulated read error"
        else
          original_binread.call(path)
        end
      end

      File.stub(:binread, stub_binread) do
        # Simulate the initializer logic
        simulate_zeitwerk_integration(app_root, loader)

        # Verify that app/admin/portals was NOT ignored due to read error
        unexpected_path = app_root.join("app/admin/portals").to_s
        assert_not_includes ignored_dirs, unexpected_path,
                            "Expected app/admin/portals to NOT be ignored when file read fails"
      end
    end
  end
end
