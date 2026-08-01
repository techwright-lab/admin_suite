# frozen_string_literal: true

require "test_helper"

# Fixtures for the gem-provided searchable_select search endpoint
# (ResourcesController#search). Self-contained per the pattern established in
# authorization_test.rb/pagination_and_stats_test.rb: `rake test
# TEST=test/integration/searchable_select_search_test.rb` must work with no
# other test file's fixtures loaded.
module SearchableSelectFixtures
  class Company
    extend ActiveModel::Naming

    attr_reader :id, :name, :secret

    def initialize(id:, name:, secret: nil)
      @id = id
      @name = name
      @secret = secret
    end

    def self.records
      @records ||= (1..30).map { |n| new(id: n, name: "Widget #{n}") } +
        [ new(id: 1000, name: "Acme Corp", secret: "unicorn-marker") ]
    end

    def self.all = ReadOnlyResourceFixtures::Relation.new(records)
    def self.column_names = %w[id name secret]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }

    def self.find(id)
      records.find { |r| r.id.to_s == id.to_s } || raise(ActiveRecord::RecordNotFound)
    end

    # Fakes AR's `where(sql, binds)` well enough to exercise the real
    # production predicate (`Admin::Base::FilterBuilder.search_predicate`)
    # end to end in this database-free dummy app: parses the field name(s)
    # out of the "<field> ILIKE :search" text the predicate builds -- which
    # only ever contains names from the resource's declared `searchable`
    # whitelist -- and substring-matches only *those* fields. A term that
    # only appears in a non-searchable field (`secret`, below) can therefore
    # never match, mirroring real ILIKE restricted to real whitelisted
    # columns.
    def self.where(conditions, binds = {})
      term = binds[:search].to_s.delete_prefix("%").delete_suffix("%").downcase
      fields = conditions.scan(/(\w+) ILIKE :search/).flatten
      matches = records.select { |r| fields.any? { |f| r.public_send(f).to_s.downcase.include?(term) } }
      ReadOnlyResourceFixtures::Relation.new(matches)
    end

    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name, "secret" => secret }
  end

  # Declares an index (so it's a real, otherwise-normal resource) but never
  # calls `searchable`, leaving `searchable_fields` empty -- one of the
  # hostile-input shapes the task brief calls out explicitly. `where` raises
  # so any test that reaches it proves the guard in
  # `ResourcesController#search_results` failed to short-circuit before
  # querying.
  class NoSearchWidget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id:, name:)
      @id = id
      @name = name
    end

    def self.all = ReadOnlyResourceFixtures::Relation.new([ new(id: 1, name: "Solo widget") ])
    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(_id) = new(id: 1, name: "Solo widget")

    def self.where(*)
      raise "must not query a resource with no searchable fields declared"
    end

    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name }
  end

  # No `index` block at all -- `index_config` itself is nil, a stricter
  # version of the "no searchable fields" case above.
  class NoIndexWidget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id:, name:)
      @id = id
      @name = name
    end

    def self.all = ReadOnlyResourceFixtures::Relation.new([ new(id: 1, name: "Bare widget") ])
    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(_id) = new(id: 1, name: "Bare widget")

    def self.where(*)
      raise "must not query a resource with no index config at all"
    end

    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name }
  end

  # Exercises `render_searchable_select`'s URL resolution: one field left to
  # resolve its search URL automatically via `resource:`, one overridden
  # with an explicit String `collection:` (must still win -- unchanged host
  # behavior).
  class Deal
    extend ActiveModel::Naming

    attr_accessor :id, :company_id, :vendor_id

    def initialize(id: nil, company_id: nil, vendor_id: nil)
      @id = id
      @company_id = company_id
      @vendor_id = vendor_id
    end

    def self.column_names = %w[id company_id vendor_id]
    def persisted? = !id.nil?
    def new_record? = !persisted?

    # render_form_field unconditionally calls `resource.errors[field.name]`
    # for every field; no test here exercises a validation error, so a Hash
    # defaulting to `[]` is sufficient (same rationale as
    # layout_assets_test.rb's MarkdownWidget).
    def errors
      Hash.new([])
    end
  end
end

module Admin
  module Resources
    class SearchableSelectCompanyResource < Admin::Base::Resource
      model SearchableSelectFixtures::Company
      portal :ops
      section :observability

      index do
        searchable :name
        columns { column :name }
      end
    end

    class SearchableSelectNoSearchWidgetResource < Admin::Base::Resource
      model SearchableSelectFixtures::NoSearchWidget
      portal :ops
      section :observability

      index do
        columns { column :name }
      end
    end

    class SearchableSelectNoIndexWidgetResource < Admin::Base::Resource
      model SearchableSelectFixtures::NoIndexWidget
      portal :ops
      section :observability
    end

    class SearchableSelectDealResource < Admin::Base::Resource
      model SearchableSelectFixtures::Deal
      portal :ops
      section :observability

      form do
        field :company_id, type: :searchable_select, resource: :searchable_select_companies
        field :vendor_id, type: :searchable_select, collection: "/custom/vendor/search"
      end
    end
  end
end

module AdminSuite
  class SearchableSelectSearchTest < ActionDispatch::IntegrationTest
    COMPANIES_SEARCH = "/internal/admin_suite/ops/searchable_select_companies/search"
    NO_SEARCH = "/internal/admin_suite/ops/searchable_select_no_search_widgets/search"
    NO_INDEX = "/internal/admin_suite/ops/searchable_select_no_index_widgets/search"

    def with_authorize(hook)
      saved = AdminSuite.config.authorize
      AdminSuite.config.authorize = hook
      yield
    ensure
      AdminSuite.config.authorize = saved
    end

    test "returns matching records as a bare JSON array with id and name" do
      get COMPANIES_SEARCH, params: { q: "Acme" }
      assert_response :success

      body = JSON.parse(response.body)
      assert_instance_of Array, body
      assert_equal [ { "id" => 1000, "name" => "Acme Corp" } ], body
    end

    test "the response is a bare array, never {results: [...]}" do
      get COMPANIES_SEARCH, params: { q: "Widget" }
      assert_response :success
      assert_kind_of Array, JSON.parse(response.body)
    end

    test "caps results at 25 even when more records match" do
      get COMPANIES_SEARCH, params: { q: "Widget" }
      assert_response :success
      assert_equal 25, JSON.parse(response.body).size
    end

    test "empty q returns an empty array, not the whole table" do
      get COMPANIES_SEARCH, params: { q: "" }
      assert_response :success
      assert_equal [], JSON.parse(response.body)
    end

    test "a missing q param returns an empty array" do
      get COMPANIES_SEARCH
      assert_response :success
      assert_equal [], JSON.parse(response.body)
    end

    test "only searches the resource's declared searchable fields, never an arbitrary column" do
      get COMPANIES_SEARCH, params: { q: "unicorn-marker" }
      assert_response :success
      assert_equal [], JSON.parse(response.body),
        "a term that only exists in a non-searchable column must never match"
    end

    test "a resource with no searchable fields declared returns empty results without querying the model" do
      get NO_SEARCH, params: { q: "widget" }
      assert_response :success
      assert_equal [], JSON.parse(response.body)
    end

    test "a resource with no index config at all returns empty results without querying the model" do
      get NO_INDEX, params: { q: "widget" }
      assert_response :success
      assert_equal [], JSON.parse(response.body)
    end

    test "unknown resource name 404s" do
      get "/internal/admin_suite/ops/totally_unregistered_things/search", params: { q: "x" }
      assert_response :not_found
    end

    test "a resource name with path traversal characters 404s rather than erroring" do
      get "/internal/admin_suite/ops/#{ERB::Util.url_encode('../../etc/passwd')}/search", params: { q: "x" }
      assert_response :not_found
    end

    test "denies with 403 when config.authorize denies" do
      with_authorize(->(**) { false }) do
        get COMPANIES_SEARCH, params: { q: "Acme" }
      end
      assert_response :forbidden
    end

    test "authorize hook receives action: :read, the resource, a nil record, and the controller" do
      captured = nil
      hook = lambda do |actor:, action:, resource:, record:, controller:|
        captured = { action: action, resource: resource, record: record, controller: controller.class }
        true
      end

      with_authorize(hook) { get COMPANIES_SEARCH, params: { q: "Acme" } }

      assert_equal :read, captured[:action]
      assert_equal Admin::Resources::SearchableSelectCompanyResource, captured[:resource]
      assert_nil captured[:record]
      assert_equal AdminSuite::ResourcesController, captured[:controller]
    end

    test "unregistered resource name 404s before the authorize hook ever runs" do
      hook_called = false
      with_authorize(->(**) { hook_called = true; false }) do
        get "/internal/admin_suite/ops/totally_unregistered_things/search", params: { q: "x" }
      end
      refute hook_called, "authorize hook must not run for an unregistered resource name"
    end

    test "a very long q does not crash and does not leak the table" do
      get COMPANIES_SEARCH, params: { q: "a" * 10_000 }
      assert_response :success
      assert_equal [], JSON.parse(response.body)
    end

    test "SQL metacharacters in q do not crash and are treated as a literal search term" do
      get COMPANIES_SEARCH, params: { q: "'; DROP TABLE companies; --" }
      assert_response :success
      assert_equal [], JSON.parse(response.body)
    end

    test "render_searchable_select resolves field resource: to the gem's search endpoint" do
      get "/internal/admin_suite/ops/searchable_select_deals/new"
      assert_response :success
      assert_includes response.body, "/internal/admin_suite/ops/searchable_select_companies/search"
    end

    test "a String collection: still overrides the default resource: URL, unchanged" do
      get "/internal/admin_suite/ops/searchable_select_deals/new"
      assert_response :success
      assert_includes response.body, "/custom/vendor/search"
    end
  end
end
