# frozen_string_literal: true

module Public
  # Base controller for all public-facing pages
  #
  # Provides unauthenticated access for marketing pages like homepage,
  # contact, pricing, etc. All public controllers should inherit from this class.
  #
  # @example
  #   class Public::HomeController < Public::BaseController
  #     def index
  #       # Public homepage action
  #     end
  #   end
  class BaseController < ApplicationController
    allow_unauthenticated_access

    layout "public"

    private

    # Redirects authenticated users to dashboard
    #
    # Can be used in before_action to redirect logged-in users
    # away from public pages like login/register.
    # @return [void]
    def redirect_authenticated_users
      redirect_to interview_applications_path if authenticated?
    end
  end
end

