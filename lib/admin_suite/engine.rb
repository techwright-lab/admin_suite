# frozen_string_literal: true

require "fileutils"

module AdminSuite
  class Engine < ::Rails::Engine
    isolate_namespace AdminSuite

    initializer "admin_suite.inflections" do
      # Engine namespace uses `UI` (all-caps). Without this, Zeitwerk expects `Ui`.
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym "UI"
      end
    end

    initializer "admin_suite.host_dsl_ignore", before: :setup_main_autoloader do |app|
      AdminSuite::HostAutoloadPolicy.apply!(app)
    end

    initializer "admin_suite.admin_dsl" do
      # Ensure core DSL types are loaded in all environments (including test).
      require "admin/base/resource"
      require "admin/base/filter_builder"
      require "admin/base/action_executor"
      require "admin/base/action_handler"
    end

    initializer "admin_suite.watchable_dirs" do |app|
      next unless Rails.env.development?

      # Make local-engine edits reload without a full server restart.
      app.config.watchable_dirs[root.join("app").to_s] = %w[rb erb js css]
      app.config.watchable_dirs[root.join("lib").to_s] = %w[rb]
      app.config.watchable_dirs[root.join("config").to_s] = %w[rb]
    end

    initializer "admin_suite.host_watchable_dirs" do |app|
      next unless Rails.env.development?

      # Rails only re-runs `to_prepare` callbacks (see
      # "admin_suite.definition_reload" below) when it detects a change in a
      # watched path -- by default, `config.autoload_paths` +
      # `eager_load_paths` + `watchable_files` + `watchable_dirs`.
      # `app/admin*` directories are covered automatically (Rails treats
      # every directory under `app/` as an autoload path). But
      # `config/admin_suite/**` -- the *recommended*, deliberately
      # non-autoload location for resource/portal/dashboard/action
      # definitions (see "admin_suite.configuration" below) -- isn't in any
      # of those by default, so editing only a file there would never be
      # noticed. Watch it explicitly.
      host_admin_suite_config_dir = Rails.root.join("config/admin_suite")
      next unless host_admin_suite_config_dir.exist?

      app.config.watchable_dirs[host_admin_suite_config_dir.to_s] = %w[rb]
    end

    initializer "admin_suite.definition_reload" do |app|
      next unless Rails.env.development?

      # Drives DefinitionLoader's development live-reload. Rails runs
      # `to_prepare` callbacks once at boot and again on any request where
      # it detects a change in a watched path (see
      # "admin_suite.host_watchable_dirs" above) -- NOT unconditionally on
      # every request (that's gated by `config.reload_classes_only_on_change`,
      # true by default; see Rails::Application::Finisher#set_clear_dependencies_hook).
      # Clearing the loaded flags here, rather than inside `load!` itself,
      # is what bounds a reload to at most once per such request instead of
      # once per `load!` call (application_controller.rb's `navigation_items`
      # alone triggers several per request).
      app.reloader.to_prepare do
        AdminSuite::DefinitionLoader.reset_for_new_request!
      end
    end

    initializer "admin_suite.assets", before: "propshaft" do |app|
      # Make engine JS/CSS available to the host asset pipeline (Propshaft/Sprockets).
      app.config.assets.paths << root.join("app/javascript")
      app.config.assets.paths << root.join("app/assets")
    end

    initializer "admin_suite.importmap", before: "importmap" do |app|
      # Make engine-provided JS available to host apps using importmap-rails.
      if app.config.respond_to?(:importmap) && app.config.importmap.respond_to?(:paths)
        app.config.importmap.paths << root.join("config/importmap.rb")
      end
    end

    initializer "admin_suite.configuration" do
      # Provide sensible defaults for host apps.
      AdminSuite.configure do |config|
        if config.resource_globs.blank?
          config.resource_globs = [
            Rails.root.join("config/admin_suite/resources/*.rb").to_s,
            Rails.root.join("app/admin/resources/*.rb").to_s
          ]
        end

        if config.action_globs.blank?
          config.action_globs = [
            Rails.root.join("config/admin_suite/actions/*.rb").to_s,
            Rails.root.join("app/admin/actions/*.rb").to_s
          ]
        end

        if config.portal_globs.blank?
          config.portal_globs = [
            Rails.root.join("config/admin_suite/portals/*.rb").to_s,
            Rails.root.join("app/admin/portals/*.rb").to_s,
            Rails.root.join("app/admin_suite/portals/*.rb").to_s
          ]
        end

        if config.dashboard_globs.blank?
          config.dashboard_globs = [
            Rails.root.join("config/admin_suite/dashboard.rb").to_s,
            Rails.root.join("config/admin_suite/dashboard/*.rb").to_s,
            Rails.root.join("app/admin_suite/dashboard.rb").to_s,
            Rails.root.join("app/admin_suite/dashboard/*.rb").to_s
          ]
        end

        self.class.apply_default_portals!(config)
      end
    end

    # Applies the engine's built-in default portals, unless the host has
    # explicitly assigned `config.portals` itself (even to `{}`). Extracted
    # from the "admin_suite.configuration" initializer so it is directly
    # testable without booting a full Rails app.
    def self.apply_default_portals!(config)
      return if config.portals_configured? || config.portals.present?

      config.send(:default_portals!, {
        ops: { label: "Ops Portal", icon: "settings", color: :amber, order: 10 },
        email: { label: "Email Portal", icon: "inbox", color: :emerald, order: 20 },
        ai: { label: "AI Portal", icon: "cpu", color: :cyan, order: 30 },
        assistant: { label: "Assistant Portal", icon: "message-circle", color: :violet, order: 40 }
      })
    end

    initializer "admin_suite.tailwind_build" do
      next unless Rails.env.development?

      # In development, ensure the engine stylesheet exists so the UI is usable
      # without requiring host-specific Tailwind setup.
      output = Rails.root.join("app/assets/builds/admin_suite_tailwind.css")
      next if output.exist?

      input = root.join("app/assets/tailwind/admin_suite.css")
      FileUtils.mkdir_p(output.dirname)

      system("tailwindcss", "-i", input.to_s, "-o", output.to_s)
    rescue StandardError
      # Best effort only; missing stylesheet will show up immediately in the UI.
    end
  end
end
