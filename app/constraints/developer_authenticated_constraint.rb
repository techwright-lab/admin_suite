# frozen_string_literal: true

# Routing constraint that requires developer authentication via TechWright SSO
#
# Used to protect routes like Mission Control Jobs that need admin access
# but don't go through the normal controller authentication flow.
#
# @example Usage in routes
#   constraints DeveloperAuthenticatedConstraint.new do
#     mount MissionControl::Jobs::Engine, at: "/jobs"
#   end
#
class DeveloperAuthenticatedConstraint
  # Checks if the request has a valid developer session
  #
  # @param request [ActionDispatch::Request] The incoming request
  # @return [Boolean] True if developer is authenticated
  def matches?(request)
    developer_id = request.session[:developer_id]
    return false if developer_id.blank?

    Developer.enabled.exists?(id: developer_id)
  end
end
