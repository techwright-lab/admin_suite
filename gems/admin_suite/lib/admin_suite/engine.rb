# frozen_string_literal: true

require "fileutils"

module AdminSuite
  class Engine < ::Rails::Engine
    isolate_namespace AdminSuite

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
        config.resource_globs = [ Rails.root.join("app/admin/resources/*.rb").to_s ] if config.resource_globs.blank?
        config.portal_globs = [ Rails.root.join("app/admin/portals/*.rb").to_s ] if config.portal_globs.blank?
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
