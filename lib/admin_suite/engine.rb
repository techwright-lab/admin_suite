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

    initializer "admin_suite.host_dsl_ignore" do
      # Host apps often keep AdminSuite definition files under `app/admin/**`.
      #
      # Rails treats `app/*` as Zeitwerk roots, so `app/admin` becomes its own root.
      # That means Zeitwerk expects constants like `Resources::UserResource` from:
      #   app/admin/resources/user_resource.rb
      # but most apps define:
      #   Admin::Resources::UserResource
      #
      # To avoid production eager-load `Zeitwerk::NameError`s, we ignore these
      # directories for Zeitwerk and load definition files ourselves (via globs).
      host_ignore_dirs = [
        Rails.root.join("app/admin_suite"),
        Rails.root.join("app/admin/resources"),
        Rails.root.join("app/admin/actions"),
        Rails.root.join("app/admin/base")
      ]

      # `app/admin/portals` may contain DSL-only portal dashboards (no constants).
      # Ignore it only if it appears to contain AdminSuite portal DSL definitions.
      host_admin_portals_dir = Rails.root.join("app/admin/portals")
      if host_admin_portals_dir.exist?
        portal_files = Dir[host_admin_portals_dir.join("**/*.rb").to_s]
        contains_admin_suite_portals =
          portal_files.any? do |file|
            content = File.binread(file)
            content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
            portal_dsl_pattern = /(::)?AdminSuite\s*\.\s*portal\b/
            portal_dsl_pattern.match?(content)
          rescue StandardError
            false
          end

        host_ignore_dirs << host_admin_portals_dir if contains_admin_suite_portals
      end

      Rails.autoloaders.each do |loader|
        host_ignore_dirs.each do |dir|
          loader.ignore(dir) if dir.exist?
        end
      end
    end

    initializer "admin_suite.admin_dsl" do
      # Ensure core DSL types are loaded in all environments (including test).
      require "admin/base/resource"
      require "admin/base/filter_builder"
      require "admin/base/action_executor"
      require "admin/base/action_handler"
    end

    initializer "admin_suite.reloader" do |app|
      # Reset the handlers_loaded flag in development so handlers are reloaded
      # when code changes. This ensures the expensive glob operation happens at
      # most once per request (or code reload) rather than on every NameError.
      if Rails.env.development?
        app.reloader.to_prepare do
          Admin::Base::ActionExecutor.handlers_loaded = false
        end
      end
    end

    initializer "admin_suite.watchable_dirs" do |app|
      next unless Rails.env.development?

      # Make local-engine edits reload without a full server restart.
      app.config.watchable_dirs[root.join("app").to_s] = %w[rb erb js css]
      app.config.watchable_dirs[root.join("lib").to_s] = %w[rb]
      app.config.watchable_dirs[root.join("config").to_s] = %w[rb]
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

        config.portals = {
          ops: { label: "Ops Portal", icon: "settings", color: :amber, order: 10 },
          email: { label: "Email Portal", icon: "inbox", color: :emerald, order: 20 },
          ai: { label: "AI Portal", icon: "cpu", color: :cyan, order: 30 },
          assistant: { label: "Assistant Portal", icon: "message-circle", color: :violet, order: 40 }
        } if config.portals.blank?
      end
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
