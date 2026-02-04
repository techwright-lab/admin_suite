# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"
require "minitest/autorun"
require "active_support/test_case"
require "action_dispatch/testing/integration"

# Ensure the engine is loaded (and its initializers run).
require "admin_suite"
