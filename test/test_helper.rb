ENV["RAILS_ENV"] ||= "test"

# Optional coverage reporting:
#   COVERAGE=1 bundle exec rails test
COVERAGE_ENABLED = ENV.key?("COVERAGE") && !ENV["COVERAGE"].to_s.empty?
if COVERAGE_ENABLED
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch
    add_filter "/test/"
    add_filter "/vendor/"
  end
end

require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/assistant_tool_contract_assertions"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors) unless COVERAGE_ENABLED

    # Use FactoryBot instead of fixtures
    include FactoryBot::Syntax::Methods
    include ActiveJob::TestHelper
    include AssistantToolContractAssertions

    # Add more helper methods to be used by all tests here...

    # Ensure Current attributes never leak between tests (critical with parallelization).
    setup do
      Current.reset

      # Enable auth flows by default in test environment (feature-flagged via Setting).
      # This must run in each parallel worker process.
      Setting.set(name: "user_login_enabled", value: true)
      Setting.set(name: "username_password_login_enabled", value: true)
      Setting.set(name: "user_sign_up_enabled", value: true)
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
