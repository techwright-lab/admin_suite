# frozen_string_literal: true

# AdminSuite configuration (host app adapter layer).
AdminSuite.configure do |config|
  # Hook called as a before_action inside the engine.
  # config.authenticate = ->(controller) { ... }
  config.authenticate = nil

  # Actor used for actions/auditing/authorization.
  # config.current_actor = ->(controller) { ... }
  config.current_actor = ->(controller) { controller.respond_to?(:current_user) ? controller.current_user : nil }

  # Optional authorization hook (Pundit/CanCan/ActionPolicy/custom).
  # config.authorize = ->(actor, action:, subject:, resource:, controller:) { true }
  config.authorize = nil

  # Resource definition file globs (host app can override).
  config.resource_globs = [
    Rails.root.join("app/admin/resources/*.rb").to_s
  ]

  # Portal metadata (host app can override).
  config.portals = {
    ops: { label: "Ops Portal", icon: "settings", color: :amber, order: 10 }
  }

  # Custom renderers:
  # config.custom_renderers[:my_renderer] = ->(record, view_context) { ... }
end
