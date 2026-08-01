# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class DefinitionLoaderTest < ActiveSupport::TestCase
    def with_globs(kind, paths)
      key = { resources: :resource_globs, portals: :portal_globs,
              dashboards: :dashboard_globs, actions: :action_globs }.fetch(kind)
      saved = AdminSuite.config.public_send(key)
      AdminSuite.config.public_send("#{key}=", paths)
      AdminSuite::DefinitionLoader.reset!(kind)
      yield
    ensure
      AdminSuite.config.public_send("#{key}=", saved)
      AdminSuite::DefinitionLoader.reset!(kind)
    end

    # Stubs Rails.env for the duration of the block, restoring it afterward.
    # Used to exercise DefinitionLoader's development-only reload branch,
    # which never runs under the dummy app's normal (test-env) CI suite.
    def with_rails_env(name)
      original = Rails.env
      Rails.env = ActiveSupport::EnvironmentInquirer.new(name.to_s)
      yield
    ensure
      Rails.env = original
    end

    test "loads each matching file once in non-development environments" do
      Dir.mktmpdir do |dir|
        marker = File.join(dir, "count.txt")
        File.write(File.join(dir, "thing.rb"), "File.write(#{marker.inspect}, File.exist?(#{marker.inspect}) ? File.read(#{marker.inspect}).to_i + 1 : 1)")
        with_globs(:dashboards, [ File.join(dir, "*.rb") ]) do
          2.times { AdminSuite::DefinitionLoader.load!(:dashboards) }
          assert_equal 1, File.read(marker).to_i
        end
      end
    end

    test "empty globs are a no-op and do not re-scan" do
      with_globs(:dashboards, []) do
        assert_nothing_raised { 2.times { AdminSuite::DefinitionLoader.load!(:dashboards) } }
      end
    end

    test "a raising definition file surfaces the error in test env" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "bad.rb"), "raise 'boom'")
        with_globs(:dashboards, [ File.join(dir, "*.rb") ]) do
          error = assert_raises(RuntimeError) { AdminSuite::DefinitionLoader.load!(:dashboards) }
          assert_equal "boom", error.message
        end
      end
    end

    test "an unknown kind is rejected" do
      assert_raises(ArgumentError) { AdminSuite::DefinitionLoader.load!(:nonsense) }
    end

    # --- Development-mode reload coverage ---
    #
    # The dummy app never runs in development, so this branch has never
    # executed in CI (per Task 9 brief). It matters because it changes
    # per-kind reload semantics: dev now resets + reloads on every call,
    # for all four kinds uniformly (previously portals/dashboards did this,
    # inconsistently, and resources/actions did not at all).

    test "in development, reloads on every call even when nothing changed" do
      Dir.mktmpdir do |dir|
        marker = File.join(dir, "count.txt")
        File.write(File.join(dir, "thing.rb"), "File.write(#{marker.inspect}, File.exist?(#{marker.inspect}) ? File.read(#{marker.inspect}).to_i + 1 : 1)")
        with_globs(:dashboards, [ File.join(dir, "*.rb") ]) do
          with_rails_env(:development) do
            3.times { AdminSuite::DefinitionLoader.load!(:dashboards) }
            assert_equal 3, File.read(marker).to_i
          end
        end
      end
    end

    test "in development, resets the kind's registry before reloading so removed files disappear" do
      Dir.mktmpdir do |dir|
        portal_file = File.join(dir, "temp_portal.rb")
        File.write(portal_file, "AdminSuite.portal(:definition_loader_dev_test) {}")

        with_globs(:portals, [ File.join(dir, "*.rb") ]) do
          with_rails_env(:development) do
            AdminSuite::DefinitionLoader.load!(:portals)
            assert AdminSuite::PortalRegistry.all.key?(:definition_loader_dev_test),
                   "expected the portal defined by the glob'd file to be registered"

            File.delete(portal_file)

            AdminSuite::DefinitionLoader.load!(:portals)
            assert_not AdminSuite::PortalRegistry.all.key?(:definition_loader_dev_test),
                       "expected the removed portal to disappear after the next dev-mode reload"
          end
        end
      end
    ensure
      AdminSuite::PortalRegistry.reset!
    end

    test "in development, reset runs even when the glob list is empty" do
      # Guards the bug in the old ensure_portals_loaded!: it returned before
      # resetting when no files matched, so a portal removed via the *last*
      # remaining file never got cleared. DefinitionLoader must reset first.
      #
      # The portal is registered *inside* with_globs (after its own reset!)
      # so that this test's assertion exercises `load!`'s own reset, not
      # with_globs's unrelated setup-time reset.
      with_globs(:portals, []) do
        AdminSuite.portal(:definition_loader_dev_test_2) {}
        assert AdminSuite::PortalRegistry.all.key?(:definition_loader_dev_test_2)

        with_rails_env(:development) do
          AdminSuite::DefinitionLoader.load!(:portals)
          assert_not AdminSuite::PortalRegistry.all.key?(:definition_loader_dev_test_2),
                     "expected the reset lambda to run even with an empty glob list"
        end
      end
    end

    # --- Per-kind wiring sanity (guards against a kind pointed at the wrong globals) ---

    test "resources kind is backed by Admin::Base::Resource's registry" do
      # `Admin::Base::Resource.registered_resources` accumulates real
      # resources registered elsewhere in the suite at file-load time (e.g.
      # fixtures in test_helper.rb and other test files) and is *already*
      # non-empty before this test runs. That means the resources kind's
      # `loaded?` (registered_resources.any?) is already true, so the
      # non-development branch would short-circuit without touching the
      # filesystem -- this has to run in "development" (which never checks
      # `loaded?`) to actually exercise the glob+load path, and must restore
      # every pre-existing entry afterward rather than calling
      # `reset_registry!` bare, which would wipe every other test's fixtures
      # for the rest of the run (see Task 9 brief's note on registries
      # leaking across tests).
      resources_before = Admin::Base::Resource.registered_resources.dup
      saved_globs = AdminSuite.config.resource_globs

      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "definition_loader_dev_resource.rb"), <<~RUBY)
          module Admin
            module Resources
              class DefinitionLoaderDevResource < Admin::Base::Resource
              end
            end
          end
        RUBY

        AdminSuite.config.resource_globs = [ File.join(dir, "*.rb") ]

        with_rails_env(:development) do
          AdminSuite::DefinitionLoader.load!(:resources)
          assert Admin::Base::Resource.registered_resources.any? { |r| r.name == "Admin::Resources::DefinitionLoaderDevResource" }
        end
      end
    ensure
      AdminSuite.config.resource_globs = saved_globs
      Admin::Base::Resource.reset_registry!
      resources_before.each { |r| Admin::Base::Resource.registered_resources << r }
    end

    test "actions kind is backed by ActionExecutor.handlers_loaded" do
      with_globs(:actions, []) do
        Admin::Base::ActionExecutor.handlers_loaded = false
        AdminSuite::DefinitionLoader.load!(:actions)
        assert Admin::Base::ActionExecutor.handlers_loaded
      end
    ensure
      Admin::Base::ActionExecutor.handlers_loaded = false
    end

    test "dashboards kind is backed by AdminSuite.config.root_dashboard_loaded" do
      with_globs(:dashboards, []) do
        AdminSuite.reset_root_dashboard!
        AdminSuite::DefinitionLoader.load!(:dashboards)
        assert AdminSuite.config.root_dashboard_loaded
      end
    end
  end
end
