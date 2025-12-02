# frozen_string_literal: true

module Public
  # Controller for the public homepage
  #
  # Handles the main marketing landing page for Gleania.
  class HomeController < BaseController
    # GET /
    #
    # Renders the public homepage with all marketing sections.
    # Authenticated users can optionally be redirected to their dashboard.
    def index
      # Optionally redirect authenticated users to dashboard
      # Uncomment the next line if you want to auto-redirect logged-in users
      # redirect_to interview_applications_path if authenticated?
    end
  end
end

