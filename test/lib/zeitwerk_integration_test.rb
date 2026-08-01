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

    # A minimal stand-in for the Rails::Application instance HostAutoloadPolicy
    # is invoked with in production: it only needs `#root` and a
    # `#config.autoload_paths` / `#config.eager_load_paths` that respond to
    # `#delete` (exercised only by the "maps app/admin..." test below).
    def create_fake_app(root)
      config = Struct.new(:autoload_paths, :eager_load_paths).new([], [])
      Struct.new(:root, :config).new(Pathname.new(root), config)
    end

    test "ignores app/admin/portals when it contains AdminSuite portal DSL" do
      # Create app/admin/portals directory with portal DSL file
      portals_dir = File.join(@temp_dir, "app", "admin", "portals")
      FileUtils.mkdir_p(portals_dir)
      File.write(
        File.join(portals_dir, "ops_portal.rb"),
        "AdminSuite.portal :ops do\n  # portal config\nend"
      )

      app = create_fake_app(@temp_dir)
      loader, ignored_dirs, _pushed_dirs = create_tracked_loader
      AdminSuite::HostAutoloadPolicy.apply!(app, loaders: [ loader ])

      # Verify that app/admin/portals was ignored
      expected_path = app.root.join("app/admin/portals").to_s
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

      app = create_fake_app(@temp_dir)
      loader, ignored_dirs, _pushed_dirs = create_tracked_loader
      AdminSuite::HostAutoloadPolicy.apply!(app, loaders: [ loader ])

      # Verify that app/admin/portals was NOT ignored
      unexpected_path = app.root.join("app/admin/portals").to_s
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

      app = create_fake_app(@temp_dir)
      loader, ignored_dirs, _pushed_dirs = create_tracked_loader
      AdminSuite::HostAutoloadPolicy.apply!(app, loaders: [ loader ])

      # Verify that app/admin_suite was ignored
      expected_path = app.root.join("app/admin_suite").to_s
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

      app = create_fake_app(@temp_dir)
      loader, ignored_dirs, _pushed_dirs = create_tracked_loader
      AdminSuite::HostAutoloadPolicy.apply!(app, loaders: [ loader ])

      # Verify that app/admin/portals was ignored due to presence of portal DSL
      expected_path = app.root.join("app/admin/portals").to_s
      assert_includes ignored_dirs, expected_path,
                      "Expected app/admin/portals to be ignored when any file contains portal DSL"
    end

    test "handles file read errors gracefully" do
      # Create app/admin/portals directory with a file
      portals_dir = File.join(@temp_dir, "app", "admin", "portals")
      FileUtils.mkdir_p(portals_dir)
      test_file = File.join(portals_dir, "test.rb")
      File.write(test_file, "AdminSuite.portal :ops do; end")

      app = create_fake_app(@temp_dir)
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
        AdminSuite::HostAutoloadPolicy.apply!(app, loaders: [ loader ])

        # Verify that app/admin/portals was NOT ignored due to read error
        unexpected_path = app.root.join("app/admin/portals").to_s
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

      app = create_fake_app(@temp_dir)
      loader, _ignored_dirs, pushed_dirs = create_tracked_loader
      AdminSuite::HostAutoloadPolicy.apply!(app, loaders: [ loader ])

      assert pushed_dirs.any? { |h| h[:path] == app.root.join("app/admin").to_s && h[:namespace] == Admin },
             "Expected app/admin to be pushed with namespace Admin when files define Admin::* constants"
    end

    test "does not map app/admin when it contains only top-level constants" do
      resources_dir = File.join(@temp_dir, "app", "admin", "resources")
      FileUtils.mkdir_p(resources_dir)
      File.write(
        File.join(resources_dir, "user_resource.rb"),
        "module Resources\n  class UserResource; end\nend\n"
      )

      app = create_fake_app(@temp_dir)
      loader, _ignored_dirs, pushed_dirs = create_tracked_loader
      AdminSuite::HostAutoloadPolicy.apply!(app, loaders: [ loader ])

      assert pushed_dirs.none? { |h| h[:path] == app.root.join("app/admin").to_s },
             "Expected app/admin to NOT be pushed when files contain only top-level constants"
    end
  end
end
