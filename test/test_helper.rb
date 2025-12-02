ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Use FactoryBot instead of fixtures
    include FactoryBot::Syntax::Methods

    # Add more helper methods to be used by all tests here...
    
    # Helper to sign in a user
    def sign_in_as(user)
      post session_url, params: { email_address: user.email_address, password: "password" }
    end
  end
end

# Configure OmniAuth for testing
OmniAuth.config.test_mode = true
OmniAuth.config.add_mock(:google_oauth2, {
  provider: "google_oauth2",
  uid: "123456789",
  info: {
    email: "test@example.com",
    name: "Test User"
  },
  credentials: {
    token: "mock_token",
    refresh_token: "mock_refresh_token",
    expires_at: Time.current.to_i + 3600
  }
})
