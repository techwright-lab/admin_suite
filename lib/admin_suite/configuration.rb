# frozen_string_literal: true

module AdminSuite
  # Configuration object for AdminSuite.
  class Configuration
    attr_accessor :authenticate,
      :current_actor,
      :authorize,
      :auth_strategy,
      :auth_options,
      :allow_unauthenticated,
      :skip_host_before_actions,
      :logout_path,
      :logout_method,
      :logout_label,
      :resource_globs,
      :action_globs,
      :portal_globs,
      :dashboard_globs,
      :custom_renderers,
      :icon_renderer,
      :docs_url,
      :docs_path,
      :partials,
      :theme,
      :host_stylesheet,
      :root_dashboard_title,
      :root_dashboard_description,
      :root_dashboard_definition,
      :root_dashboard_loaded,
      :on_action_executed,
      :resolve_action_handler

    attr_reader :portals

    # Records that the host explicitly assigned portals (even to `{}`), so
    # the engine's built-in defaults are never re-applied over explicit
    # host intent. See #portals_configured?.
    def portals=(value)
      @portals_configured = true
      @portals = value
    end

    # True once the host has assigned `config.portals` itself, distinct
    # from the engine having applied its own defaults.
    def portals_configured?
      @portals_configured == true
    end

    def initialize
      @authenticate = nil
      @current_actor = nil
      @authorize = nil
      @auth_strategy = nil
      @auth_options = {}
      @allow_unauthenticated = false
      @skip_host_before_actions = [ :require_authentication ]
      @logout_path = nil
      @logout_method = :delete
      @logout_label = "Log out"
      @resource_globs = []
      @action_globs = []
      @portal_globs = []
      @dashboard_globs = []
      @portals = {}
      @portals_configured = false
      @custom_renderers = {}
      @icon_renderer = nil
      @docs_url = nil
      @docs_path = Rails.root.join("docs")
      @partials = {}
      @theme = { primary: :indigo, secondary: :purple }
      @host_stylesheet = nil
      @root_dashboard_title = nil
      @root_dashboard_description = nil
      @root_dashboard_definition = nil
      @root_dashboard_loaded = false
      @on_action_executed = nil
      @resolve_action_handler = nil
    end

    # Sets the built-in default portals without marking portals as
    # host-configured.
    #
    # Engine-internal: public so `AdminSuite::Engine.apply_default_portals!`
    # can call it directly, without reaching past `Configuration`'s privacy
    # via `send`. Not part of the host-facing configuration API -- a host
    # app should never call this itself; use `config.portals = { ... }` (or
    # `config.portals = {}` to suppress the built-in defaults). This
    # deliberately bypasses the public `portals=` writer so gem-applied
    # defaults stay distinguishable from an explicit host assignment
    # (including an explicit `{}` meant to suppress defaults).
    def default_portals!(value)
      @portals = value
    end
  end
end
