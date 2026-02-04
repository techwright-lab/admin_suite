# frozen_string_literal: true

module AdminSuite
  # Configuration object for AdminSuite.
  class Configuration
    attr_accessor :authenticate,
      :current_actor,
      :authorize,
      :resource_globs,
      :portal_globs,
      :portals,
      :custom_renderers,
      :icon_renderer,
      :docs_url,
      :partials,
      :theme,
      :host_stylesheet,
      :tailwind_cdn,
      :on_action_executed,
      :resolve_action_handler

    def initialize
      @authenticate = nil
      @current_actor = nil
      @authorize = nil
      @resource_globs = []
      @portal_globs = []
      @portals = {}
      @custom_renderers = {}
      @icon_renderer = nil
      @docs_url = nil
      @partials = {}
      @theme = { primary: :indigo, secondary: :purple }
      @host_stylesheet = nil
      @tailwind_cdn = true
      @on_action_executed = nil
      @resolve_action_handler = nil
    end
  end
end
