# frozen_string_literal: true

# Base controller for API v1 endpoints
# Provides JSON-only responses and authentication
#
# Note: CSRF protection is enabled (default Rails behavior) since these APIs
# are consumed by same-origin JavaScript using session-based auth.
# The frontend includes the X-CSRF-Token header in all mutating requests.
class Api::V1::BaseController < ApplicationController
  before_action :authenticate_api_user!

  private

  # Authenticates user for API requests
  # Uses session-based auth (same as web app)
  # @return [void]
  def authenticate_api_user!
    unless Current.user
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
