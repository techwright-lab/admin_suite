# frozen_string_literal: true

require "test_helper"

class QueryTest < ActiveSupport::TestCase
  Config = Struct.new(:model_class, :index_config)
  IndexConfig = Struct.new(
    :per_page,
    :includes_list,
    :searchable_fields,
    :filters_list,
    :default_sort,
    :sortable_fields,
    :default_sort_direction
  )

  class RaisingIncludesRelation < ReadOnlyResourceFixtures::Relation
    def includes(*)
      raise ArgumentError, "bad association"
    end
  end

  class Model
    class << self
      attr_accessor :relation

      def all = relation
    end
  end

  test "per_page falls back to the DSL value when no param is given" do
    query = AdminSuite::Query.new(resource_config: config_with(per_page: 30), params: {})

    assert_equal 30, query.per_page
  end

  test "per_page honours the param" do
    query = AdminSuite::Query.new(resource_config: config_with(per_page: 30), params: { per_page: "50" })

    assert_equal 50, query.per_page
  end

  test "per_page clamps to MAX_PAGE_SIZE" do
    query = AdminSuite::Query.new(resource_config: config_with(per_page: 30), params: { per_page: "999999" })

    assert_equal AdminSuite::Query::MAX_PAGE_SIZE, query.per_page
  end

  test "per_page falls back for junk and non-positive values" do
    ["abc", "0", "-5", nil, "", [], true].each do |value|
      query = AdminSuite::Query.new(resource_config: config_with(per_page: 30), params: { per_page: value })

      assert_equal 30, query.per_page, "per_page: #{value.inspect} must fall back to the DSL value"
    end
  end

  test "a raising includes degrades to the unoptimized scope instead of raising" do
    relation = RaisingIncludesRelation.new([])
    Model.relation = relation
    query = AdminSuite::Query.new(resource_config: config_with(per_page: 25, includes: [:nope]), params: {})

    assert_same relation, query.scope
  end

  private

  def config_with(per_page:, includes: [])
    Config.new(Model, IndexConfig.new(per_page, includes, [], [], nil, [], :asc))
  end
end
