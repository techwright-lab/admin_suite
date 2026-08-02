# frozen_string_literal: true

module AdminSuite
  # Configuration object for AdminSuite.
  class Configuration
    attr_accessor :authenticate,
      :current_actor,
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

    attr_reader :portals, :authorize

    # The authorize hook's keywords are validated at assignment rather than
    # at call time: a hook with the pre-0.6.0 `controller:` keyword would
    # otherwise raise deep inside a request (or, worse, bind `context:` to
    # nothing and silently mis-evaluate). Failing in the initializer puts
    # the error where the mistake is.
    REQUIRED_AUTHORIZE_KEYWORDS = %i[actor action resource record context].freeze

    def authorize=(hook)
      if hook
        parameters =
          if hook.respond_to?(:parameters)
            hook.parameters
          elsif hook.respond_to?(:call)
            # A plain object implementing #call is a legitimate hook, and its
            # signature is still introspectable -- one level down, on the
            # method itself. Falling back here keeps the keyword guard working
            # for callables instead of skipping validation for them.
            hook.method(:call).parameters
          else
            raise ArgumentError,
              "config.authorize must be callable (a lambda, proc, method, or an object responding to #call), got #{hook.class}."
          end

        keywords = parameters.filter_map { |type, name| name if %i[key keyreq].include?(type) }

        # A `**` splat absorbs every keyword, so such a hook cannot be missing one --
        # `->(**) {}` reports `[[:keyrest, :**]]` and no :key/:keyreq at all. Test
        # doubles and coarse "deny everything" hooks are written this way; rejecting
        # them would be a false positive.
        accepts_rest = parameters.any? { |type, _| type == :keyrest }

        missing = accepts_rest ? [] : REQUIRED_AUTHORIZE_KEYWORDS - keywords
        # The `extra` check still runs against explicitly named keywords even when a
        # splat is present: `->(controller:, **)` is exactly the mistake this guard
        # exists to catch, and the splat would otherwise hide it -- `controller:`
        # binds to nil while `**` quietly swallows the real arguments, so the hook
        # mis-evaluates instead of failing.
        extra = keywords - REQUIRED_AUTHORIZE_KEYWORDS

        unless missing.empty? && extra.empty?
          raise ArgumentError, <<~MESSAGE
            config.authorize must accept exactly (actor:, action:, resource:, record:, context:).
            Missing: #{missing.inspect}. Unexpected: #{extra.inspect}.
            As of admin_suite 0.6.0 the `controller:` keyword is replaced by `context:`,
            which carries `surface` (:web or :mcp), `controller` (web only) and `request`.
          MESSAGE
        end
      end

      @authorize = hook
    end

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
