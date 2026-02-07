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
      # Host apps may store AdminSuite DSL files under `app/admin_suite/**` and
      # `app/admin/portals/**`.
      #
      # These are side-effect DSL files (they do not define constants), so Zeitwerk
      # must ignore them to avoid eager-load `Zeitwerk::NameError`s in production.

      admin_suite_app_dir = Rails.root.join("app/admin_suite")
      admin_dir = Rails.root.join("app/admin")
      admin_portals_dir = Rails.root.join("app/admin/portals")

      # If the host uses `Admin::*` constants inside `app/admin/**`, Rails' default
      # autoload root (`app/admin`) would expect top-level constants like
      # `Resources::UserResource`. We fix that by mapping `app/admin` to `Admin`.
      # This avoids requiring host apps to add their own Zeitwerk initializer.
      if admin_dir.exist? && self.class.host_admin_namespace_files?(admin_dir)
        admin_dir_s = admin_dir.to_s
        app.config.autoload_paths.delete(admin_dir_s)
        app.config.eager_load_paths.delete(admin_dir_s)

        # Ensure `Admin` exists so Zeitwerk can use it as a namespace.
        module ::Admin; end

        Rails.autoloaders.main.push_dir(admin_dir, namespace: ::Admin)
      end

      Rails.autoloaders.each do |loader|
        loader.ignore(admin_suite_app_dir) if admin_suite_app_dir.exist?

        next unless admin_portals_dir.exist?

        loader.ignore(admin_portals_dir) if self.class.contains_admin_suite_portal_dsl?(admin_portals_dir)
      end
    end

    def self.host_admin_namespace_files?(admin_dir)
      # True if any file under app/admin appears to define `Admin::*` constants.
      Dir[admin_dir.join("**/*.rb").to_s].any? do |file|
        next false if file.include?("/portals/")

        content = File.binread(file)
        content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

        content.match?(/\b(module|class)\s+Admin\b/) ||
          content.match?(/\b(module|class)\s+Admin::/)
      rescue StandardError
        false
      end
    end

    def self.contains_admin_suite_portal_dsl?(admin_portals_dir)
      portal_files = Dir[admin_portals_dir.join("**/*.rb").to_s]
      portal_files.any? do |file|
        content = File.binread(file)
        content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        portal_dsl_pattern = /(::)?AdminSuite\s*\.\s*portal\b/
        portal_dsl_pattern.match?(content)
      rescue StandardError
        false
      end
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
