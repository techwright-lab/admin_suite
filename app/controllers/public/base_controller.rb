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

    before_action :set_default_meta_tags

    private

    # Sets baseline SEO meta tags for public pages.
    #
    # Individual controllers/actions can override via `set_meta_tags`.
    # @return [void]
    def set_default_meta_tags
      set_meta_tags(
        site: "Gleania",
        reverse: true,
        separator: "—",
        description: "Gleania helps you track interviews, gather feedback, and grow your skills with AI-powered reflection.",
        canonical: request.original_url,
        og: {
          site_name: "Gleania",
          type: "website",
          url: request.original_url
        },
        twitter: {
          card: "summary_large_image"
        }
      )
    end

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
