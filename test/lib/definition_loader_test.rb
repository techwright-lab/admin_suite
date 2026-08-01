# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class DefinitionLoaderTest < ActiveSupport::TestCase
    def with_globs(kind, paths)
      key = { resources: :resource_globs, portals: :portal_globs,
              dashboards: :dashboard_globs, actions: :action_globs }.fetch(kind)
      saved = AdminSuite.config.public_send(key)
      AdminSuite.config.public_send("#{key}=", paths)
      restore_registry = snapshot_registry(kind)
      AdminSuite::DefinitionLoader.reset!(kind)
      yield
    ensure
      AdminSuite.config.public_send("#{key}=", saved)
      restore_registry.call
    end

    # `DefinitionLoader.reset!` clears shared global state (the resource
    # registry, the portal registry) that accumulates real fixtures
    # registered by *other* tests at file-load time -- e.g.
    # `test/integration/read_only_resource_test.rb`'s `ReadOnlyWidgetResource`
    # and `test_helper.rb`'s fixture resources are registered once, forever,
    # before any test runs. An earlier version of this helper called
    # `reset!` bare and broke `navigation_sections_test.rb` whenever it ran
    # afterward. Snapshot what's there before resetting and restore exactly
    # that afterward, rather than trusting it to come back on its own.
    def snapshot_registry(kind)
      case kind
      when :resources
        before = Admin::Base::Resource.registered_resources.dup
        lambda do
          Admin::Base::Resource.reset_registry!
          before.each { |r| Admin::Base::Resource.registered_resources << r }
        end
      when :portals
        before = AdminSuite::PortalRegistry.all.dup
        lambda do
          AdminSuite::PortalRegistry.reset!
          before.each_value { |definition| AdminSuite::PortalRegistry.register(definition) }
        end
      else
        -> { AdminSuite::DefinitionLoader.reset!(kind) }
      end
    end

    # Stubs Rails.env for the duration of the block, restoring it afterward.
    # Used to exercise DefinitionLoader's `load` (vs `require`) file-loading
    # mode, which never runs under the dummy app's normal (test-env) CI
    # suite.
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
    # Per the Task 9 erratum: `load!` itself must NEVER reset a kind's
    # registry automatically (in development or otherwise) -- only
    # `reset_for_new_request!` (wired into Rails' `to_prepare` by the
    # engine, simulating "a new request began") or a test's explicit
    # `reset!`/`with_globs` may do that. These tests simulate the request
    # boundary explicitly rather than assuming `load!` reloads on every call.

    test "in development, load! does not reload on repeated calls (bounded to the request boundary)" do
      Dir.mktmpdir do |dir|
        marker = File.join(dir, "count.txt")
        File.write(File.join(dir, "thing.rb"), "File.write(#{marker.inspect}, File.exist?(#{marker.inspect}) ? File.read(#{marker.inspect}).to_i + 1 : 1)")
        with_globs(:dashboards, [ File.join(dir, "*.rb") ]) do
          # reset_for_new_request! resets *every* dev_resettable kind, not
          # just :dashboards -- it also touches PortalRegistry and
          # handlers_loaded, which is exactly the shared global state
          # Finding 3 established a snapshot/restore discipline for. Wrap
          # it here too, or this test becomes seed-dependent the day some
          # other test registers a portal at file-load time.
          restore_portals = snapshot_registry(:portals)
          restore_actions = snapshot_registry(:actions)

          with_rails_env(:development) do
            3.times { AdminSuite::DefinitionLoader.load!(:dashboards) }
            assert_equal 1, File.read(marker).to_i,
                         "expected load! to load the file once, not once per call, without an intervening reset"
            assert AdminSuite.config.root_dashboard_loaded,
                   "expected load! to mark the kind loaded in development too, not only outside it"

            AdminSuite::DefinitionLoader.reset_for_new_request!
            AdminSuite::DefinitionLoader.load!(:dashboards)
            assert_equal 2, File.read(marker).to_i,
                         "expected reset_for_new_request! to make the next load! call reload"
          end
        ensure
          restore_portals.call
          restore_actions.call
        end
      end
    end

    test "in development, a portal removed from disk only disappears after reset_for_new_request!, not on a bare repeated load!" do
      Dir.mktmpdir do |dir|
        portal_file = File.join(dir, "temp_portal.rb")
        File.write(portal_file, "AdminSuite.portal(:definition_loader_dev_test) {}")

        with_globs(:portals, [ File.join(dir, "*.rb") ]) do
          with_rails_env(:development) do
            AdminSuite::DefinitionLoader.load!(:portals)
            assert AdminSuite::PortalRegistry.all.key?(:definition_loader_dev_test),
                   "expected the portal defined by the glob'd file to be registered"

            File.delete(portal_file)

            # No reset happened -- load! alone must not touch the registry.
            AdminSuite::DefinitionLoader.load!(:portals)
            assert AdminSuite::PortalRegistry.all.key?(:definition_loader_dev_test),
                   "expected the portal to remain registered without an intervening reset_for_new_request!"

            AdminSuite::DefinitionLoader.reset_for_new_request!
            AdminSuite::DefinitionLoader.load!(:portals)
            assert_not AdminSuite::PortalRegistry.all.key?(:definition_loader_dev_test),
                       "expected the removed portal to disappear once reset_for_new_request! ran"
          end
        end
      end
    end

    test "reset_for_new_request! resets portals, dashboards and actions, but never resources" do
      # This is the regression this task's erratum exists for: resource
      # registration happens only via Class#inherited, which never refires
      # on a reopened (already-defined) class, so resetting the resource
      # registry between requests would empty it permanently after the
      # first reset+reload cycle. See the :resources KINDS entry.
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "resource.rb"), <<~RUBY)
          module Admin
            module Resources
              class ResetForNewRequestResource < Admin::Base::Resource
              end
            end
          end
        RUBY

        with_globs(:resources, [ File.join(dir, "*.rb") ]) do
          with_globs(:portals, []) do
            with_globs(:dashboards, []) do
              with_globs(:actions, []) do
                AdminSuite.portal(:reset_for_new_request_test) {}
                AdminSuite::DefinitionLoader.load!(:resources)
                Admin::Base::ActionExecutor.handlers_loaded = true
                AdminSuite.config.root_dashboard_loaded = true

                AdminSuite::DefinitionLoader.reset_for_new_request!

                assert_not AdminSuite::PortalRegistry.all.key?(:reset_for_new_request_test),
                           "expected portals to be reset"
                assert_not AdminSuite.config.root_dashboard_loaded, "expected dashboards to be reset"
                assert_not Admin::Base::ActionExecutor.handlers_loaded, "expected actions to be reset"
                assert Admin::Base::Resource.registered_resources.any? { |r| r.name == "Admin::Resources::ResetForNewRequestResource" },
                       "expected resources to survive reset_for_new_request! untouched"
              end
            end
          end
        end
      end
    end

    # The assertion whose absence let the erratum's bug through: the
    # dev-mode resources test that existed before this fix only ever loaded
    # a brand-new constant exactly once -- the one case where Class#inherited
    # actually fires. Calling load! twice against the *same* file, with no
    # reset in between, is what a single request actually does (base_helper's
    # `portal_color`/`portal_icon` both re-enter `navigation_items`, which
    # calls `ensure_resources_loaded!` again).
    test "load!(:resources) called twice against the same file leaves the registry populated after the second call" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "definition_loader_dev_resource.rb"), <<~RUBY)
          module Admin
            module Resources
              class DefinitionLoaderDevResource < Admin::Base::Resource
              end
            end
          end
        RUBY

        with_globs(:resources, [ File.join(dir, "*.rb") ]) do
          with_rails_env(:development) do
            2.times { AdminSuite::DefinitionLoader.load!(:resources) }

            assert Admin::Base::Resource.registered_resources.any? { |r| r.name == "Admin::Resources::DefinitionLoaderDevResource" },
                   "expected the resource to still be registered after a second load! call"
          end
        end
      end
    end

    # --- Per-kind wiring sanity (guards against a kind pointed at the wrong globals) ---

    test "resources kind is backed by Admin::Base::Resource's registry" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "definition_loader_dev_resource.rb"), <<~RUBY)
          module Admin
            module Resources
              class DefinitionLoaderDevResource2 < Admin::Base::Resource
              end
            end
          end
        RUBY

        with_globs(:resources, [ File.join(dir, "*.rb") ]) do
          AdminSuite::DefinitionLoader.load!(:resources)
          assert Admin::Base::Resource.registered_resources.any? { |r| r.name == "Admin::Resources::DefinitionLoaderDevResource2" }
        end
      end
    end

    test "actions kind is backed by ActionExecutor.handlers_loaded" do
      with_globs(:actions, []) do
        Admin::Base::ActionExecutor.handlers_loaded = false
        AdminSuite::DefinitionLoader.load!(:actions)
        assert Admin::Base::ActionExecutor.handlers_loaded
      end
    end

    test "dashboards kind is backed by AdminSuite.config.root_dashboard_loaded" do
      with_globs(:dashboards, []) do
        AdminSuite::DefinitionLoader.load!(:dashboards)
        assert AdminSuite.config.root_dashboard_loaded
      end
    end
  end
end
