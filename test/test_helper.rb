# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

# Configure SimpleCov for coverage reporting
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    add_filter "/test/"
    add_filter "/config/"
    add_group "Models", "app/models"
    add_group "Controllers", "app/controllers"
    add_group "Helpers", "app/helpers"
    add_group "Libraries", "lib"
  end
end

require_relative "dummy/config/environment"
require "minitest/autorun"
require "active_support/test_case"
require "action_dispatch/testing/integration"

# Ensure the engine is loaded (and its initializers run).
require "admin_suite"
