# frozen_string_literal: true

module AdminSuite
  class McpController < ApplicationController
    # JSON-RPC clients do not have a browser CSRF token. Authentication still
    # runs through ApplicationController, and this endpoint is read-only.
    skip_before_action :verify_authenticity_token, raise: false

    def create
      return head :not_found unless AdminSuite.config.mcp.enabled
      return head :unauthorized unless admin_suite_actor
      # Headless clients omit Origin. Browser clients must belong to this
      # host; Rails' HostAuthorization middleware remains the Host gate.
      return head :forbidden if request.origin && request.origin != request.base_url

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
  end
end
