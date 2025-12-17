# frozen_string_literal: true

module Public
  # Controller for public legal pages (Privacy, Terms, Cookies).
  #
  # These pages are required for OAuth verification and are accessible without authentication.
  class LegalController < BaseController
    # GET /privacy
    def privacy
      set_meta_tags(title: "Privacy Policy", canonical: privacy_url)
    end

    # GET /terms
    def terms
      set_meta_tags(title: "Terms of Service", canonical: terms_url)
    end

    # GET /cookies
    #
    # Named `cookies_policy` to avoid colliding with ActionController's `cookies` accessor.
    def cookies_policy
      set_meta_tags(title: "Cookie Policy", canonical: cookies_url)
      render :cookies
    end
  end
end
