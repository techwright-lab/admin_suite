# frozen_string_literal: true

# AdminSuite configuration (host app adapter layer).
AdminSuite.configure do |config|
  # --- Authentication (REQUIRED — AdminSuite fails closed) ---
  #
  # Built-in HTTP Basic (reads ADMIN_SUITE_USERNAME / ADMIN_SUITE_PASSWORD):
  config.auth_strategy = :http_basic
  # config.auth_options = { username: ENV["ADMIN_SUITE_USERNAME"], password: ENV["ADMIN_SUITE_PASSWORD"] }
  #
  # Or a custom strategy (e.g. your SSO). Subclass AdminSuite::Auth::Strategy,
  # return an actor from #authenticate!(controller), and register it:
  #   AdminSuite::Auth.register(:my_sso, MySsoStrategy)
  #   config.auth_strategy = :my_sso
  #
  # Or the legacy lambda (still supported):
  # config.authenticate = ->(controller) { ... render/redirect to deny ... }
  #
  # Development/test only — run without authentication (ignored in production):
  # config.allow_unauthenticated = true

  # Host before_actions the engine skips (it authenticates itself):
  # config.skip_host_before_actions = [ :require_authentication ]

  # Actor used for actions/auditing/authorization when your strategy does not
  # provide one (legacy fallback):
  config.current_actor = ->(controller) { controller.respond_to?(:current_user) ? controller.current_user : nil }

  # Authorization hook — called for every resource request.
  # Signature: ->(actor:, action:, resource:, record:, controller:) { true }
  # action is one of :read, :create, :update, :destroy, :execute.
  # nil hook: every authenticated request is allowed (auth remains the gate).
  # Hook return of false or nil: 403 Forbidden (fail closed; no disclose/mutate).
  # config.authorize = ->(actor:, action:, resource:, record:, controller:) { true }
  config.authorize = nil

  # Optional sign-out action in the topbar.
  # config.logout_path = ->(view) { view.main_app.logout_path }
  # config.logout_method = :delete
  # config.logout_label = "Log out"

  # Resource definition file globs (host app can override).
  config.resource_globs = [
    Rails.root.join("config/admin_suite/resources/*.rb").to_s,
    Rails.root.join("app/admin/resources/*.rb").to_s
  ]

  # Action handler file globs (host app can override).
  #
  # Files typically define `Admin::Actions::<Resource><Action>Action` handlers.
  config.action_globs = [
    Rails.root.join("config/admin_suite/actions/*.rb").to_s,
    Rails.root.join("app/admin/actions/*.rb").to_s
  ]

  # Portal dashboard DSL globs (host app can override).
  # Files typically call `AdminSuite.portal :ops do ... end`
  config.portal_globs = [
    Rails.root.join("config/admin_suite/portals/*.rb").to_s,
    # Prefer `app/admin_suite/portals` for DSL files so Zeitwerk never expects
    # application constants (e.g. `Admin::Portals::OpsPortal` for
    # `app/admin/portals/ops_portal.rb`) during eager load.
    Rails.root.join("app/admin_suite/portals/*.rb").to_s,
    # Legacy/fallback: still support portals defined under app/admin/portals.
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

  # Optional docs link shown in the sidebar.
  # config.docs_url = "https://..."
  config.docs_url = nil

  # Docs viewer source folder (host app filesystem).
  # Defaults to Rails.root/docs.
  config.docs_path = Rails.root.join("docs")

  # Partial overrides.
  # config.partials[:flash] = "my/shared/flash"
  # config.partials[:panel_stat] = "my/admin/panels/stat"

  # Custom renderers:
  # config.custom_renderers[:my_renderer] = ->(record, view_context) { ... }
end
