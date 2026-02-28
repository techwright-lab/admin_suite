# frozen_string_literal: true

require "test_helper"
require "tmpdir"

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
      pushed_dirs = []

      loader.define_singleton_method(:ignore) do |path|
        ignored_dirs << path.to_s
      end

      loader.define_singleton_method(:push_dir) do |path, namespace:|
        pushed_dirs << { path: path.to_s, namespace: namespace }
      end

      [ loader, ignored_dirs, pushed_dirs ]
    end

    # Helper method that simulates the Zeitwerk integration logic from engine.rb
    def simulate_zeitwerk_integration(app_root, loader)
      admin_suite_app_dir = app_root.join("app/admin_suite")
      admin_dir = app_root.join("app/admin")
      admin_portals_dir = app_root.join("app/admin/portals")

      # Map app/admin -> Admin namespace if files define Admin::* constants.
      if admin_dir.exist?
        rb_files = Dir[admin_dir.join("**/*.rb").to_s]
        rb_files.reject! { |f| f.include?("/portals/") }

        host_uses_admin_namespace =
          rb_files.any? do |file|
            content = File.binread(file).encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
            content.match?(/\b(module|class)\s+Admin\b/) || content.match?(/\b(module|class)\s+Admin::/)
          rescue StandardError
            false
          end

        loader.push_dir(admin_dir, namespace: Admin) if host_uses_admin_namespace
      end

      loader.ignore(admin_suite_app_dir) if admin_suite_app_dir.exist?

      # Ignore portal DSL files (side-effect DSL, not constants).
      if admin_portals_dir.exist?
        portal_files = Dir[admin_portals_dir.join("**/*.rb").to_s]
        contains_admin_suite_portals =
          portal_files.any? do |file|
            content = File.binread(file).encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
            content.match?(/(::)?AdminSuite\s*\.\s*portal\b/)
          rescue StandardError
            false
          end

        loader.ignore(admin_portals_dir) if contains_admin_suite_portals
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
      loader, ignored_dirs, _pushed_dirs = create_tracked_loader
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
      loader, ignored_dirs, _pushed_dirs = create_tracked_loader
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
      loader, ignored_dirs, _pushed_dirs = create_tracked_loader
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
      loader, ignored_dirs, _pushed_dirs = create_tracked_loader
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
      loader, ignored_dirs, _pushed_dirs = create_tracked_loader

      # Temporarily override File.binread to simulate read errors
      original_binread = File.singleton_class.instance_method(:binread)

      File.singleton_class.define_method(:binread) do |path|
        if path == test_file
          raise StandardError, "Simulated read error"
        else
          original_binread.bind(File).call(path)
        end
      end

      begin
        # Simulate the initializer logic
        simulate_zeitwerk_integration(app_root, loader)

        # Verify that app/admin/portals was NOT ignored due to read error
        unexpected_path = app_root.join("app/admin/portals").to_s
        assert_not_includes ignored_dirs, unexpected_path,
                            "Expected app/admin/portals to NOT be ignored when file read fails"
      ensure
        # Restore original method
        File.singleton_class.define_method(:binread, original_binread)
      end
    end

    test "maps app/admin to Admin namespace when files define Admin constants" do
      resources_dir = File.join(@temp_dir, "app", "admin", "resources")
      FileUtils.mkdir_p(resources_dir)
      File.write(
        File.join(resources_dir, "user_resource.rb"),
        "module Admin\n  module Resources\n    class UserResource; end\n  end\nend\n"
      )

      app_root = Pathname.new(@temp_dir)
      loader, _ignored_dirs, pushed_dirs = create_tracked_loader
      simulate_zeitwerk_integration(app_root, loader)

      assert pushed_dirs.any? { |h| h[:path] == app_root.join("app/admin").to_s && h[:namespace] == Admin },
             "Expected app/admin to be pushed with namespace Admin when files define Admin::* constants"
    end

    test "does not map app/admin when it contains only top-level constants" do
      resources_dir = File.join(@temp_dir, "app", "admin", "resources")
      FileUtils.mkdir_p(resources_dir)
      File.write(
        File.join(resources_dir, "user_resource.rb"),
        "module Resources\n  class UserResource; end\nend\n"
      )

      app_root = Pathname.new(@temp_dir)
      loader, _ignored_dirs, pushed_dirs = create_tracked_loader
      simulate_zeitwerk_integration(app_root, loader)

      assert pushed_dirs.none? { |h| h[:path] == app_root.join("app/admin").to_s },
             "Expected app/admin to NOT be pushed when files contain only top-level constants"
    end
  end
end
