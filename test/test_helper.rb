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

# Same rationale as above: base_helper.rb's show-page/association rendering
# checks `record.is_a?(ActiveRecord::Base)` to distinguish a real AR
# association from a plain in-memory relation stand-in. Supply just the bare
# constant so that check can run (and return false for our PORO fixtures)
# without requiring the full active_record/railtie in this DB-free dummy app.
unless defined?(ActiveRecord::Base)
  module ActiveRecord
    class Base; end
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

# The dummy app is database-free and `ActiveRecord::Base` above is a bare
# stub class, so every other fixture in this suite is a PORO and
# `active_record_base?` is false for all of them -- every AR-dependent path
# (`auto_admin_suite_path_for`, `format_table_cell`'s AR branch) is
# otherwise unreachable by tests. Subclassing the stub gives a fixture that
# genuinely satisfies `active_record_base?`, with no database and no
# railtie required. Established here (Task 3, phase 2b) because it's
# reused by later tasks (4, 7); those tasks' own test files each `require
# "test_helper"`, so this is visible to them even when a single test file
# is run in isolation via `rake test TEST=...` -- unlike a fixture defined
# only in association_linking_test.rb, which would not be.
module LinkingFixtures
  class Company < ActiveRecord::Base
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id: 7, name: "Acme Corp")
      @id = id
      @name = name
    end

    def self.all = ReadOnlyResourceFixtures::Relation.new([ new ])
    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(_id) = new
    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name }
  end
end

module Admin
  module Resources
    # Registered so `auto_admin_suite_path_for` can resolve a real path for
    # `LinkingFixtures::Company` instances (it looks up `registered_resources`
    # by `model_class`). Never call `Admin::Base::Resource.reset_registry!` in
    # a test: `inherited` fires only on class creation, so a reset-then-reload
    # would permanently empty the registry for the rest of the run.
    class LinkingCompanyResource < Admin::Base::Resource
      model LinkingFixtures::Company
      portal :ops
      section :observability
    end
  end
end
