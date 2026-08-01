# frozen_string_literal: true

require "test_helper"

# Fixtures for the `includes:` DSL option (Task 4, phase 2b). A scope that
# genuinely supports `#includes` and records/validates the call, so the
# controller's "apply when the scope responds" and "degrade when
# `.includes` itself raises" paths are both exercisable end-to-end. The
# `LinkingFixtures::Deal`/`ReadOnlyResourceFixtures::Relation` pair (no
# `#includes` at all) already covers the "skip silently" path -- reused
# below rather than duplicated.
module IndexIncludesFixtures
  class IncludesCapableRelation
    include Enumerable

    KNOWN_ASSOCIATIONS = %i[company owner].freeze

    attr_reader :includes_calls

    def initialize(records)
      @records = records
      @includes_calls = []
    end

    def each(&block) = @records.each(&block)
    def count(*) = @records.count
    def offset(*) = self
    def limit(*) = self

    # Mirrors real ActiveRecord's eventual `ActiveRecord::AssociationNotFoundError`
    # for an unknown association name -- raised here at call time (rather
    # than lazily, as real AR does) so the controller's rescue path around
    # the `.includes` call site is directly exercisable.
    def includes(*associations)
      flat = associations.flatten
      invalid = flat.reject { |a| KNOWN_ASSOCIATIONS.include?(a.respond_to?(:to_sym) ? a.to_sym : a) }
      raise ArgumentError, "Association named #{invalid.first.inspect} was not found" if invalid.any?

      @includes_calls << flat
      self
    end
  end

  class Widget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id:, name:)
      @id = id
      @name = name
    end

    RELATION = IncludesCapableRelation.new([ new(id: 1, name: "Widget One") ])

    def self.all = RELATION
    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(id) = all.find { |w| w.to_param == id.to_s }
    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name }
  end

  class BadWidget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id:, name:)
      @id = id
      @name = name
    end

    RELATION = IncludesCapableRelation.new([ new(id: 1, name: "Bad Widget") ])

    def self.all = RELATION
    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(id) = all.find { |w| w.to_param == id.to_s }
    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name }
  end

  # Self-contained (this file is runnable standalone via
  # `rake test TEST=test/lib/index_includes_test.rb`, so it can't reach
  # into fixtures defined only in association_linking_test.rb): a scope
  # with no `#includes` method at all, mirroring
  # `ReadOnlyResourceFixtures::Relation`, backing a resource that
  # nonetheless declares `includes :company`. Exercises the "skip
  # silently, don't raise" path.
  class NoIncludesWidget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id:, name:)
      @id = id
      @name = name
    end

    def self.all = ReadOnlyResourceFixtures::Relation.new([ new(id: 1, name: "Plain Widget") ])
    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(id) = all.find { |w| w.to_param == id.to_s }
    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name }
  end
end

module Admin
  module Resources
    class IndexIncludesWidgetResource < Admin::Base::Resource
      model IndexIncludesFixtures::Widget
      portal :ops
      section :observability

      index do
        columns { column :name }
        includes :company, :owner
      end
    end

    class IndexIncludesBadWidgetResource < Admin::Base::Resource
      model IndexIncludesFixtures::BadWidget
      portal :ops
      section :observability

      index do
        columns { column :name }
        includes :nonexistent_association
      end
    end

    class IndexIncludesNoIncludesWidgetResource < Admin::Base::Resource
      model IndexIncludesFixtures::NoIncludesWidget
      portal :ops
      section :observability

      index do
        columns { column :name }
        includes :company
      end
    end
  end
end

module AdminSuite
  class IndexIncludesTest < ActionDispatch::IntegrationTest
    test "IndexConfig#includes stores the list of associations" do
      config = Admin::Base::Resource::IndexConfig.new
      config.includes(:company, :owner)
      assert_equal [ :company, :owner ], config.includes_list
    end

    test "IndexConfig#includes defaults to an empty list" do
      assert_equal [], Admin::Base::Resource::IndexConfig.new.includes_list
    end

    test "IndexConfig#includes drops a nil association instead of storing garbage" do
      config = Admin::Base::Resource::IndexConfig.new
      config.includes(nil)
      assert_equal [], config.includes_list
    end

    test "IndexConfig#includes tolerates a String association name" do
      config = Admin::Base::Resource::IndexConfig.new
      config.includes("company")
      assert_equal [ "company" ], config.includes_list
    end

    test "the DSL exposes includes: on a resource's index_config" do
      assert_equal [ :company, :owner ], Admin::Resources::IndexIncludesWidgetResource.index_config.includes_list
    end

    test "the controller applies includes: to a scope that responds to includes" do
      IndexIncludesFixtures::Widget::RELATION.includes_calls.clear

      get "/internal/admin_suite/ops/index_includes_widgets"
      assert_response :success

      assert_equal [ [ :company, :owner ] ], IndexIncludesFixtures::Widget::RELATION.includes_calls
    end

    test "a scope whose includes raises for a bad association degrades instead of 500ing" do
      get "/internal/admin_suite/ops/index_includes_bad_widgets"
      assert_response :success
      assert_includes response.body, "Bad Widget"
    end

    test "a scope that does not respond to includes is skipped silently, not raised" do
      refute IndexIncludesFixtures::NoIncludesWidget.all.respond_to?(:includes)

      get "/internal/admin_suite/ops/index_includes_no_includes_widgets"
      assert_response :success
      assert_includes response.body, "Plain Widget"
    end
  end
end
