# frozen_string_literal: true

module AdminSuite
  class McpController < ApplicationController
    before_action :validate_mcp_origin!, prepend: true
    # Cross-origin browsers cannot send application/json without a CORS
    # preflight; form-compatible content types still require a CSRF token.
    protect_from_forgery with: :exception, unless: :mcp_json_request?

    def create
      return head :not_found unless AdminSuite.config.mcp.enabled
      return head :unauthorized unless admin_suite_actor
      return head :method_not_allowed unless request.post?

      AdminSuite::DefinitionLoader.load!(:resources)
      server = AdminSuite::Mcp.server_for(actor: admin_suite_actor, request: request)
      transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(
        server, stateless: true, allowed_hosts: [request.host]
      )
      status, headers, body = transport.handle_request(request)
      self.status = status
      headers.each { |name, value| response.set_header(name, value) }
      self.response_body = body
    end

    private

    def validate_mcp_origin!
      head :forbidden if request.origin && request.origin != request.base_url
    end

    def mcp_json_request?
      request.media_type == "application/json"
    end
  end
end
