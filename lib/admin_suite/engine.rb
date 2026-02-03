# frozen_string_literal: true

module AdminSuite
  class Engine < ::Rails::Engine
    isolate_namespace AdminSuite

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
        config.portals = {
          ops: { label: "Ops Portal", icon: "settings", color: :amber, order: 10 },
          email: { label: "Email Portal", icon: "inbox", color: :emerald, order: 20 },
          ai: { label: "AI Portal", icon: "cpu", color: :cyan, order: 30 },
          assistant: { label: "Assistant Portal", icon: "message-circle", color: :violet, order: 40 }
        } if config.portals.blank?
      end
    end
  end
end
