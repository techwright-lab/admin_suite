# frozen_string_literal: true

begin
  require "lucide-rails"
rescue LoadError
  # Host app may choose a different icon provider via `AdminSuite.config.icon_renderer`.
end

require "pagy"

# Hard dependency, declared in the gemspec but not a direct Gemfile entry in
# any host -- Bundler's `Bundler.require` only auto-requires gems declared
# directly in the Gemfile (or via `gemspec`'s own path entry), not a gem's
# *transitive* runtime dependencies. Same reasoning as `pagy` above and
# `redcarpet`/`rouge` in markdown_renderer.rb: required explicitly here so
# `turbo_frame_tag`/`turbo_stream`/the `:turbo_stream` MIME type are real
# regardless of what else the host's own Gemfile happens to require.
require "turbo-rails"

require "admin_suite/version"
require "admin_suite/deprecation"
require "admin_suite/configuration"
require "admin_suite/markdown_renderer"
require "admin_suite/theme_palette"
require "admin_suite/portal_registry"
require "admin_suite/section_definition"
require "admin_suite/portal_definition"
require "admin_suite/auth"
require "admin_suite/ui/form_field_renderer"
require "admin_suite/ui/show_value_formatter"
require "admin_suite/renderer"
require "admin_suite/renderer_registry"
require "admin_suite/renderers/json_renderer"
require "admin_suite/renderers/key_value_renderer"
require "admin_suite/renderers/table_from_renderer"
require "admin_suite/renderers/code_renderer"
require "admin_suite/renderers/legacy_gleania"
require "admin_suite/legacy_custom_renderer_procs"
require "admin_suite/definition_loader"
require "admin_suite/host_autoload_policy"
require "admin_suite/engine"

# Registered as *defaults* (register_default), not explicit registrations:
# `render_custom_section` checks a host's own `RendererRegistry.register`
# call and a host's `Admin::Renderers::<Key>Renderer` class *before* falling
# back to these, so a host following the deprecation advice below (or simply
# overriding a built-in like `:json`) actually takes effect instead of being
# silently shadowed by the gem's own boot-time registrations.
AdminSuite::RendererRegistry.register_default(:json, AdminSuite::Renderers::JsonRenderer)
AdminSuite::RendererRegistry.register_default(:key_value, AdminSuite::Renderers::KeyValueRenderer)
AdminSuite::RendererRegistry.register_default(:table_from, AdminSuite::Renderers::TableFromRenderer)
AdminSuite::RendererRegistry.register_default(:code, AdminSuite::Renderers::CodeRenderer)

# Aliases: `:json_preview`/`:code_preview` were the previous generic
# `render_custom_section` case branches (BaseHelper#render_json_preview /
# #render_code_preview, now deleted). Host resources declared against those
# keys keep working unchanged against the new built-in renderers.
AdminSuite::RendererRegistry.register_default(:json_preview, AdminSuite::Renderers::JsonRenderer)
AdminSuite::RendererRegistry.register_default(:code_preview, AdminSuite::Renderers::CodeRenderer)

# Deprecated (removal targeted at 0.6.0, moved from the originally-planned
# 0.5.0 -- both host migrations, gleania and trust_growth, are in flight):
# the four Gleania-specific LLM chat-transcript renderers. See
# `AdminSuite::Renderers::LegacyGleania` for details.
AdminSuite::RendererRegistry.register_default(:prompt_template_preview, AdminSuite::Renderers::LegacyGleania::PromptTemplateRenderer)
AdminSuite::RendererRegistry.register_default(:messages_preview, AdminSuite::Renderers::LegacyGleania::MessagesPreviewRenderer)
AdminSuite::RendererRegistry.register_default(:tool_args_preview, AdminSuite::Renderers::LegacyGleania::ToolArgsRenderer)
AdminSuite::RendererRegistry.register_default(:turn_messages_preview, AdminSuite::Renderers::LegacyGleania::TurnMessagesRenderer)

module AdminSuite
  class << self
    # @return [AdminSuite::Configuration]
    def config
      @config ||= Configuration.new
    end

    # @yieldparam config [AdminSuite::Configuration]
    # @return [AdminSuite::Configuration]
    def configure
      yield(config)
      config
    end

    # Resolves the effective authentication strategy instance.
    #
    # Precedence: explicit `config.auth_strategy` (Symbol name or Class),
    # then the legacy `config.authenticate` lambda (wrapped), then nil.
    #
    # @return [AdminSuite::Auth::Strategy, nil]
    def resolved_auth_strategy
      if config.auth_strategy
        klass = config.auth_strategy.is_a?(Class) ? config.auth_strategy : Auth.lookup(config.auth_strategy)
        klass.new(config.auth_options || {})
      elsif config.authenticate
        Auth::HostHook.new(authenticate: config.authenticate, current_actor: config.current_actor)
      end
    end

    # Defines (or updates) a portal using a Ruby DSL.
    #
    # Host apps typically place these in:
    # - `config/admin_suite/portals/*.rb` (recommended; not a Zeitwerk autoload path)
    # - `app/admin_suite/portals/*.rb` (supported; AdminSuite ignores for Zeitwerk)
    # - `app/admin/portals/*.rb` (supported; AdminSuite will ignore for Zeitwerk if files contain `AdminSuite.portal`)
    #
    # @param key [Symbol, String]
    # @yield Portal definition DSL
    # @return [AdminSuite::PortalDefinition]
    def portal(key, &block)
      definition = PortalDefinition.new(key)
      definition.instance_eval(&block) if block_given?
      PortalRegistry.register(definition)
      definition
    end

    # @return [Hash{Symbol=>AdminSuite::PortalDefinition}]
    def portal_definitions
      PortalRegistry.all
    end

    # Defines (or updates) the root dashboard shown at the engine root (`/`).
    #
    # This uses the same dashboard DSL as portal dashboards.
    #
    # Host apps typically place these in:
    # - `config/admin_suite/dashboard.rb` (recommended; not a Zeitwerk autoload path)
    # - `app/admin_suite/dashboard.rb` (supported; AdminSuite ignores for Zeitwerk)
    #
    # @yield Dashboard definition DSL
    # @return [AdminSuite::UI::DashboardDefinition]
    def root_dashboard(&block)
      config.root_dashboard_definition ||= UI::DashboardDefinition.new
      UI::DashboardDSL.new(config.root_dashboard_definition).instance_eval(&block) if block_given?
      config.root_dashboard_definition
    end

    # @return [AdminSuite::UI::DashboardDefinition, nil]
    def root_dashboard_definition
      config.root_dashboard_definition
    end

    # Clears the root dashboard definition (useful for development reloads).
    #
    # @return [void]
    def reset_root_dashboard!
      config.root_dashboard_definition = nil
      config.root_dashboard_loaded = false
    rescue StandardError
      # best-effort
    end
  end
end
