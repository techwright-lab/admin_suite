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

    test "ignores app/admin/portals when it contains AdminSuite portal DSL" do
      # Create app/admin/portals directory with portal DSL file
      portals_dir = File.join(@temp_dir, "app", "admin", "portals")
      FileUtils.mkdir_p(portals_dir)
      File.write(
        File.join(portals_dir, "ops_portal.rb"),
        "AdminSuite.portal :ops do\n  # portal config\nend"
      )

      # Create a test loader
      loader = Zeitwerk::Loader.new
      ignored_dirs = []

      # Stub the loader's ignore method to track what gets ignored
      loader.define_singleton_method(:ignore) do |path|
        ignored_dirs << path.to_s
      end

      # Simulate the initializer logic with our temp directory as root
      app_root = Pathname.new(@temp_dir)
      host_dsl_dirs = [app_root.join("app/admin_suite")]
      host_admin_portals_dir = app_root.join("app/admin/portals")

      if host_admin_portals_dir.exist?
        portal_files = Dir[host_admin_portals_dir.join("**/*.rb").to_s]
        contains_admin_suite_portals =
          portal_files.any? do |file|
            content = File.binread(file)
            content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
            content.include?("AdminSuite.portal")
          rescue StandardError
            false
          end

        host_dsl_dirs << host_admin_portals_dir if contains_admin_suite_portals
      end

      host_dsl_dirs.each do |dir|
        loader.ignore(dir) if dir.exist?
      end

      # Verify that app/admin/portals was ignored
      # Convert to string for comparison since the ignore method receives Pathname
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

      # Create a test loader
      loader = Zeitwerk::Loader.new
      ignored_dirs = []

      # Stub the loader's ignore method to track what gets ignored
      loader.define_singleton_method(:ignore) do |path|
        ignored_dirs << path.to_s
      end

      # Simulate the initializer logic with our temp directory as root
      app_root = Pathname.new(@temp_dir)
      host_dsl_dirs = [app_root.join("app/admin_suite")]
      host_admin_portals_dir = app_root.join("app/admin/portals")

      if host_admin_portals_dir.exist?
        portal_files = Dir[host_admin_portals_dir.join("**/*.rb").to_s]
        contains_admin_suite_portals =
          portal_files.any? do |file|
            content = File.binread(file)
            content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
            content.include?("AdminSuite.portal")
          rescue StandardError
            false
          end

        host_dsl_dirs << host_admin_portals_dir if contains_admin_suite_portals
      end

      host_dsl_dirs.each do |dir|
        loader.ignore(dir) if dir.exist?
      end

      # Verify that app/admin/portals was NOT ignored
      # Convert to string for comparison
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

      # Create a test loader
      loader = Zeitwerk::Loader.new
      ignored_dirs = []

      # Stub the loader's ignore method to track what gets ignored
      loader.define_singleton_method(:ignore) do |path|
        ignored_dirs << path.to_s
      end

      # Simulate the initializer logic with our temp directory as root
      app_root = Pathname.new(@temp_dir)
      host_dsl_dirs = [app_root.join("app/admin_suite")]
      host_admin_portals_dir = app_root.join("app/admin/portals")

      if host_admin_portals_dir.exist?
        portal_files = Dir[host_admin_portals_dir.join("**/*.rb").to_s]
        contains_admin_suite_portals =
          portal_files.any? do |file|
            content = File.binread(file)
            content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
            content.include?("AdminSuite.portal")
          rescue StandardError
            false
          end

        host_dsl_dirs << host_admin_portals_dir if contains_admin_suite_portals
      end

      host_dsl_dirs.each do |dir|
        loader.ignore(dir) if dir.exist?
      end

      # Verify that app/admin_suite was ignored
      # Convert to string for comparison
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

      # Create a test loader
      loader = Zeitwerk::Loader.new
      ignored_dirs = []

      # Stub the loader's ignore method to track what gets ignored
      loader.define_singleton_method(:ignore) do |path|
        ignored_dirs << path.to_s
      end

      # Simulate the initializer logic with our temp directory as root
      app_root = Pathname.new(@temp_dir)
      host_dsl_dirs = [app_root.join("app/admin_suite")]
      host_admin_portals_dir = app_root.join("app/admin/portals")

      if host_admin_portals_dir.exist?
        portal_files = Dir[host_admin_portals_dir.join("**/*.rb").to_s]
        contains_admin_suite_portals =
          portal_files.any? do |file|
            content = File.binread(file)
            content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
            content.include?("AdminSuite.portal")
          rescue StandardError
            false
          end

        host_dsl_dirs << host_admin_portals_dir if contains_admin_suite_portals
      end

      host_dsl_dirs.each do |dir|
        loader.ignore(dir) if dir.exist?
      end

      # Verify that app/admin/portals was ignored due to presence of portal DSL
      # Convert to string for comparison
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

      # Create a test loader
      loader = Zeitwerk::Loader.new
      ignored_dirs = []

      # Stub the loader's ignore method to track what gets ignored
      loader.define_singleton_method(:ignore) do |path|
        ignored_dirs << path.to_s
      end

      # Stub File.binread to raise an error
      original_binread = File.method(:binread)
      File.define_singleton_method(:binread) do |path|
        if path == test_file
          raise StandardError, "Simulated read error"
        else
          original_binread.call(path)
        end
      end

      begin
        # Simulate the initializer logic with our temp directory as root
        app_root = Pathname.new(@temp_dir)
        host_dsl_dirs = [app_root.join("app/admin_suite")]
        host_admin_portals_dir = app_root.join("app/admin/portals")

        if host_admin_portals_dir.exist?
          portal_files = Dir[host_admin_portals_dir.join("**/*.rb").to_s]
          contains_admin_suite_portals =
            portal_files.any? do |file|
              content = File.binread(file)
              content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
              content.include?("AdminSuite.portal")
            rescue StandardError
              false
            end

          host_dsl_dirs << host_admin_portals_dir if contains_admin_suite_portals
        end

        host_dsl_dirs.each do |dir|
          loader.ignore(dir) if dir.exist?
        end

        # Verify that app/admin/portals was NOT ignored due to read error
        # Convert to string for comparison
        unexpected_path = app_root.join("app/admin/portals").to_s
        assert_not_includes ignored_dirs, unexpected_path,
                            "Expected app/admin/portals to NOT be ignored when file read fails"
      ensure
        # Restore original binread
        File.define_singleton_method(:binread, original_binread)
      end
    end
  end
end
