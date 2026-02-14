# frozen_string_literal: true

module AdminSuite
  # Configuration object for AdminSuite.
  class Configuration
    attr_accessor :authenticate,
      :current_actor,
      :authorize,
      :logout_path,
      :logout_method,
      :logout_label,
      :resource_globs,
      :action_globs,
      :portal_globs,
      :dashboard_globs,
      :portals,
      :custom_renderers,
      :icon_renderer,
      :docs_url,
      :docs_path,
      :partials,
      :theme,
      :host_stylesheet,
      :tailwind_cdn,
      :root_dashboard_title,
      :root_dashboard_description,
      :root_dashboard_definition,
      :root_dashboard_loaded,
      :on_action_executed,
      :resolve_action_handler

    def initialize
      @authenticate = nil
      @current_actor = nil
      @authorize = nil
      @logout_path = nil
      @logout_method = :delete
      @logout_label = "Log out"
      @resource_globs = []
      @action_globs = []
      @portal_globs = []
      @dashboard_globs = []
      @portals = {}
      @custom_renderers = {}
      @icon_renderer = nil
      @docs_url = nil
      @docs_path = Rails.root.join("docs")
      @partials = {}
      @theme = { primary: :indigo, secondary: :purple }
      @host_stylesheet = nil
      @tailwind_cdn = true
      @root_dashboard_title = nil
      @root_dashboard_description = nil
      @root_dashboard_definition = nil
      @root_dashboard_loaded = false
      @on_action_executed = nil
      @resolve_action_handler = nil
    end
  end
end
