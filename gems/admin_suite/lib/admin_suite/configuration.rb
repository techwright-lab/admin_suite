# frozen_string_literal: true

module AdminSuite
  # Configuration object for AdminSuite.
  class Configuration
    attr_accessor :authenticate,
      :current_actor,
      :authorize,
      :resource_globs,
      :portals,
      :custom_renderers,
      :on_action_executed,
      :resolve_action_handler

    def initialize
      @authenticate = nil
      @current_actor = nil
      @authorize = nil
      @resource_globs = []
      @portals = {}
      @custom_renderers = {}
      @on_action_executed = nil
      @resolve_action_handler = nil
    end
  end
end
