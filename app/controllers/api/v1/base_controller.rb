# frozen_string_literal: true

# Base controller for API v1 endpoints
# Provides JSON-only responses and authentication
class Api::V1::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
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
