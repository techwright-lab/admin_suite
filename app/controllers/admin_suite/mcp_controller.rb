# frozen_string_literal: true

module AdminSuite
  class McpController < ApplicationController
    # JSON-RPC clients do not have a browser CSRF token. Authentication still
    # runs through ApplicationController, and this endpoint is read-only.
    skip_before_action :verify_authenticity_token, raise: false

    def create
      return head :not_found unless AdminSuite.config.mcp.enabled

      AdminSuite::DefinitionLoader.load!(:resources)
      server = AdminSuite::Mcp.server_for(actor: admin_suite_actor, request: request)
      render json: server.handle_json(request.body.read)
    end
  end
end
