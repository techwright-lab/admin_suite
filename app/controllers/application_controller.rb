class ApplicationController < ActionController::Base
  include Authentication
  include TurnstileHelper
  include Paginatable
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set layout based on authentication status
  layout :determine_layout

  # Developer (TechWright SSO) session for internal tools and AdminSuite.
  # Used by AdminSuite.config.authenticate and by Internal::Developer controllers.
  helper_method :current_developer, :developer_authenticated?

  private

  def current_developer
    @current_developer ||= ::Developer.enabled.find_by(id: session[:developer_id])
  end

  def developer_authenticated?
    current_developer.present?
  end

  def determine_layout
    if authenticated?
      "authenticated"
    else
      "application"
    end
  end

  def authenticated?
    Current.user.present?
  end
end
