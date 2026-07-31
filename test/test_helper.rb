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

# The dummy app is intentionally database-free, while the generic controller
# supports Active Record hosts. Supply only the exception type its lookup path
# rescues so show-page behavior can be exercised with an in-memory fixture.
unless defined?(ActiveRecord::RecordNotFound)
  module ActiveRecord
    class RecordNotFound < StandardError; end
  end
end

module TurboFrameTestHelper
  def turbo_frame_tag(name, **options, &block)
    content_tag(:turbo_frame, capture(&block), id: name, **options)
  end
end

ActionView::Base.include(TurboFrameTestHelper)

module ReadOnlyResourceFixtures
  class Relation
    include Enumerable

    def initialize(records)
      @records = records
    end

    def each(&block)
      @records.each(&block)
    end

    def count(*)
      @records.count
    end

    def offset(*)
      self
    end

    def limit(*)
      self
    end
  end
end
