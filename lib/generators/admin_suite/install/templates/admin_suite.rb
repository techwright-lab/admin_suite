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

  # Portal dashboard DSL globs (host app can override).
  # Files typically call `AdminSuite.portal :ops do ... end`
  config.portal_globs = [
    Rails.root.join("app/admin/portals/*.rb").to_s
  ]

  # Portal metadata (host app can override).
  config.portals = {
    ops: { label: "Ops Portal", icon: "settings", color: :amber, order: 10 }
  }

  # Theme (Tailwind color names).
  config.theme = { primary: :indigo, secondary: :purple }

  # Optional host stylesheet to include after AdminSuite's baseline CSS.
  # In apps that use Tailwind, this is typically `:app`.
  config.host_stylesheet = :app

  # Tailwind CDN fallback (helps when host doesn't compile Tailwind).
  # Disable if you provide your own Tailwind build.
  config.tailwind_cdn = true

  # Optional docs link shown in the sidebar.
  # config.docs_url = "https://..."
  config.docs_url = nil

  # Partial overrides.
  # config.partials[:flash] = "my/shared/flash"
  # config.partials[:panel_stat] = "my/admin/panels/stat"

  # Custom renderers:
  # config.custom_renderers[:my_renderer] = ->(record, view_context) { ... }
end
