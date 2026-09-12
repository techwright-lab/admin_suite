# frozen_string_literal: true

require "test_helper"

# Pins the index query path as it behaves at v0.5.0, before
# AdminSuite::Query is extracted. These assertions intentionally exercise
# routed requests and rendered rows rather than controller internals.
module IndexQueryCharacterizationFixtures
  class Relation
    include Enumerable

    attr_reader :includes_calls

    def initialize(records, offset: 0, includes_calls: [])
      @records = records
      @offset = offset
      @includes_calls = includes_calls
    end

    def each(&block) = @records.each(&block)
    def count(*) = @records.length
    def offset(value) = self.class.new(@records, offset: value, includes_calls: includes_calls)
    def limit(value) = @records[@offset, value] || []

    def where(condition = nil, *values, **bindings)
      condition = bindings if condition.nil?
      selected =
        if condition.is_a?(Hash)
          @records.select { |record| condition.all? { |field, value| record.public_send(field).to_s == value.to_s } }
        else
          term = (bindings[:search] || values.first).to_s.delete("%").downcase
          fields = condition.scan(/(\w+) ILIKE/).flatten
          @records.select { |record| fields.any? { |field| record.public_send(field).to_s.downcase.include?(term) } }
        end
      self.class.new(selected, includes_calls: includes_calls)
    end

    def order(ordering)
      field, direction = ordering.first
      sorted = @records.sort_by { |record| record.public_send(field).to_s }
      sorted.reverse! if direction.to_sym == :desc
      self.class.new(sorted, includes_calls: includes_calls)
    end

    def includes(*associations)
      includes_calls << associations
      self
    end
  end

  class BadIncludesRelation < Relation
    def includes(*) = raise(ArgumentError, "unknown association")
  end

  class Widget
    extend ActiveModel::Naming

    attr_reader :id, :name, :secret, :status

    def initialize(id:, name:, secret:, status:)
      @id = id
      @name = name
      @secret = secret
      @status = status
    end

    ROWS = [
      new(id: 1, name: "Zulu", secret: "hidden alpha", status: "open"),
      new(id: 2, name: "Alpha", secret: "hidden zulu", status: "closed"),
      new(id: 3, name: "Bravo", secret: "private", status: "open")
    ].freeze
    INCLUDES_CALLS = []

    def self.all = Relation.new(ROWS, includes_calls: INCLUDES_CALLS)
    def self.column_names = %w[id name secret status]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(id) = ROWS.find { |row| row.to_param == id.to_s }
    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name, "secret" => secret, "status" => status }
  end

  class BadIncludesWidget < Widget
    def self.all = BadIncludesRelation.new(ROWS)
  end

  class PagedWidget
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id:) = @id = id

    ROWS = (1..150).map { |id| new(id: id) }.freeze

    def self.all = Relation.new(ROWS)
    def self.column_names = %w[id]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(id) = ROWS.find { |row| row.to_param == id.to_s }
    def to_param = id.to_s
    def attributes = { "id" => id }
  end
end

module Admin
  module Resources
    class IndexQueryCharacterizationWidgetResource < Admin::Base::Resource
      model IndexQueryCharacterizationFixtures::Widget
      portal :ops
      section :observability

      index do
        searchable :name
        sortable :name, default: :name, direction: :desc
        filters { filter :status, type: :select, options: %w[open closed] }
        columns do
          column :name, sortable: true
          column :status
        end
        includes :owner
      end
    end

    class IndexQueryCharacterizationBadIncludesWidgetResource < Admin::Base::Resource
      model IndexQueryCharacterizationFixtures::BadIncludesWidget
      portal :ops
      section :observability
      index do
        columns { column :name }
        includes :missing
      end
    end

    class IndexQueryCharacterizationPagedWidgetResource < Admin::Base::Resource
      model IndexQueryCharacterizationFixtures::PagedWidget
      portal :ops
      section :observability
      index do
        columns { column :id }
        paginate 30
      end
    end
  end
end

class IndexQueryCharacterizationTest < ActionDispatch::IntegrationTest
  WIDGETS_PATH = "/internal/admin_suite/ops/index_query_characterization_widgets"
  PAGED_PATH = "/internal/admin_suite/ops/index_query_characterization_paged_widgets"

  def rendered_names
    css_select("tbody tr td:first-child").map { |cell| cell.text.strip }
  end

  def rendered_row_count = css_select("tbody tr").size

  test "default sort applies when no sort param is given" do
    get WIDGETS_PATH
    assert_equal %w[Zulu Bravo Alpha], rendered_names
  end

  test "explicit sort and direction override the default" do
    get WIDGETS_PATH, params: { sort: "name", direction: "asc" }
    assert_equal %w[Alpha Bravo Zulu], rendered_names
  end

  test "a sort param naming an undeclared field is ignored" do
    get WIDGETS_PATH, params: { sort: "secret", direction: "asc" }
    assert_equal %w[Alpha Bravo Zulu], rendered_names
  end

  test "search examines only declared searchable fields" do
    get WIDGETS_PATH, params: { search: "alpha" }
    assert_equal [ "Alpha" ], rendered_names
  end

  test "a blank search returns the unfiltered scope" do
    get WIDGETS_PATH, params: { search: " " }
    assert_equal %w[Zulu Bravo Alpha], rendered_names
  end

  test "a declared filter narrows while an undeclared filter is ignored" do
    get WIDGETS_PATH, params: { status: "open", secret: "hidden zulu" }
    assert_equal %w[Zulu Bravo], rendered_names
  end

  test "declared includes are applied" do
    IndexQueryCharacterizationFixtures::Widget::INCLUDES_CALLS.clear
    get WIDGETS_PATH
    assert_equal [ [ :owner ] ], IndexQueryCharacterizationFixtures::Widget::INCLUDES_CALLS
  end

  test "a bad includes association logs and still renders" do
    logged = []
    Rails.logger.stub(:warn, ->(message) { logged << message }) do
      get "/internal/admin_suite/ops/index_query_characterization_bad_includes_widgets"
    end
    assert_response :success
    assert_includes response.body, "Zulu"
    assert_equal 1, logged.size
  end

  test "paginate 30 yields 30 rows per page" do
    get PAGED_PATH
    assert_equal 30, rendered_row_count
  end

  test "per_page 50 overrides the DSL value" do
    get PAGED_PATH, params: { per_page: "50" }
    assert_equal 50, rendered_row_count
  end

  test "an excessive per_page clamps to 100" do
    get PAGED_PATH, params: { per_page: "999999" }
    assert_equal 100, rendered_row_count
  end

  test "invalid and zero per_page values fall back to the DSL value" do
    [ "abc", "0" ].each do |value|
      get PAGED_PATH, params: { per_page: value }
      assert_equal 30, rendered_row_count
    end
  end

  test "a leading-zero per_page parses with Integer octal semantics" do
    get PAGED_PATH, params: { per_page: "010" }
    assert_equal 8, rendered_row_count
  end
end
