# frozen_string_literal: true

module Assistant
  # Determines which tools may be proposed for a given request.
  #
  # For now this is a thin wrapper around the enabled tool registry.
  # It will grow to support per-user disables, feature flags, etc.
  class ToolPolicy
    def initialize(user:, thread:, page_context: {})
      @user = user
      @thread = thread
      @page_context = page_context.to_h.symbolize_keys
    end

    def allowed_tools
      Assistant::Tool.enabled.by_key
    end

    private

    attr_reader :user, :thread, :page_context
  end
end
