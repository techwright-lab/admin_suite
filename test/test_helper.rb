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

module RedirectFixtures
  class Widget
    extend ActiveModel::Naming

    def persisted? = true
    def to_param = "42"
  end
end

module Admin
  module Resources
    class RedirectWidgetResource < Admin::Base::Resource
      model RedirectFixtures::Widget
      portal :ops
      section :observability
    end
  end
end
RedirectFixtures::WidgetResource = Admin::Resources::RedirectWidgetResource

# Fixtures for exercising execute_model_method's exception-handling chain
# end-to-end, in the dummy app's DB-free configuration (no ActiveRecord
# loaded), which is where a bare `rescue ActiveRecord::RecordInvalid` or
# `rescue AASM::InvalidTransition` would raise NameError while handling the
# original exception instead of reporting it.
module ExceptionHandlingFixtures
  class Boomer
    extend ActiveModel::Naming

    def kaboom
      raise "actual failure message"
    end
  end

  # Named to mirror AASM::InvalidTransition (and similar state-machine gem
  # exceptions) without depending on AASM: only the class name matters to
  # the rescue chain's class-name match.
  class InvalidTransitionError < StandardError; end

  class StateMachineWidget
    extend ActiveModel::Naming

    def transition
      raise InvalidTransitionError, "cannot transition from draft to published"
    end
  end
end

module Admin
  module Resources
    class ExceptionHandlingBoomerResource < Admin::Base::Resource
      model ExceptionHandlingFixtures::Boomer
      portal :ops
      section :observability
      actions { action :kaboom }
    end

    class ExceptionHandlingStateMachineResource < Admin::Base::Resource
      model ExceptionHandlingFixtures::StateMachineWidget
      portal :ops
      section :observability
      actions { action :transition }
    end
  end
end
