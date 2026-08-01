# frozen_string_literal: true

require "test_helper"

# `LinkingFixtures::Company` (an AR-backed fixture: it genuinely subclasses
# the `ActiveRecord::Base` stub defined in test_helper.rb) and its
# registered `Admin::Resources::LinkingCompanyResource` both live in
# test_helper.rb, not here -- established there because Tasks 4 and 7 reuse
# them, and test_helper.rb is required by every test file regardless of
# which single file `rake test TEST=...` runs. Everything below is specific
# to this task's link-rendering assertions.
module LinkingFixtures
  # Same shape as Company, but deliberately never registered as an
  # Admin::Resources::* class -- exercises the "no resource registered"
  # degrade path in `auto_admin_suite_path_for`.
  class UnregisteredVendor < ActiveRecord::Base
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id: 3, name: "Ghost Vendor")
      @id = id
      @name = name
    end

    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(_id) = new
    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name }
  end

  # `item_display_title` calls `item.name` unguarded when `respond_to?(:name)`
  # is true. This record's `#name` raises, simulating a host model whose
  # display method blows up on bad data -- the point is that a single bad
  # row must degrade, not 500 the entire page.
  class RaisingCo < ActiveRecord::Base
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id: 9)
      @id = id
    end

    def name
      raise "boom: no display name for you"
    end

    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(_id) = new
    def to_param = id.to_s
    def attributes = { "id" => id }
  end

  # Simulates an unsaved/unpersisted AR record: real `ActiveRecord::Base#to_param`
  # returns nil when `persisted?` is false. `auto_admin_suite_path_for`'s
  # `resource_path(..., id: nil)` call must degrade to no-link, not 500.
  class UnpersistedVendor < ActiveRecord::Base
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize
      @id = nil
      @name = "Draft Vendor"
    end

    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(_id) = new
    def to_param = nil
    def attributes = { "id" => id, "name" => name }
  end

  # PORO host resource (mirrors the RedirectFixtures/ReadOnlyResourceFixtures
  # convention). Its index column returns each of the AR values above, and
  # its show page renders an association table where one column is itself an
  # AR value -- the two call sites Task 3 unifies (`render_column_value`'s
  # fallback branch and `format_table_cell`'s AR branch).
  class Deal
    extend ActiveModel::Naming

    attr_reader :id, :label, :company

    def initialize(id:, label:, company:)
      @id = id
      @label = label
      @company = company
    end

    def self.all = ReadOnlyResourceFixtures::Relation.new([
      new(id: 1, label: "Q3 renewal", company: Company.new),
      new(id: 2, label: "Raises on display", company: RaisingCo.new),
      new(id: 3, label: "Unpersisted vendor", company: UnpersistedVendor.new),
      new(id: 4, label: "No resource registered", company: UnregisteredVendor.new)
    ])
    def self.column_names = %w[id label]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(id) = all.find { |d| d.to_param == id.to_s }
    def to_param = id.to_s
    def attributes = { "id" => id, "label" => label }

    def line_items
      [
        LineItem.new(1, "Renewal", Company.new),
        LineItem.new(2, "Ghost line", UnregisteredVendor.new)
      ]
    end
  end

  LineItem = Struct.new(:id, :label, :company)
end

module Admin
  module Resources
    class LinkingRaisingCoResource < Admin::Base::Resource
      model LinkingFixtures::RaisingCo
      portal :ops
      section :observability
    end

    class LinkingUnpersistedVendorResource < Admin::Base::Resource
      model LinkingFixtures::UnpersistedVendor
      portal :ops
      section :observability
    end

    class LinkingDealResource < Admin::Base::Resource
      model LinkingFixtures::Deal
      portal :ops
      section :observability

      index do
        columns do
          column :label
          column :company
        end
      end

      show do
        section :line_items, association: :line_items, display: :table, columns: [ :label, :company ]
      end
    end
  end
end

module AdminSuite
  class AssociationLinkingTest < ActionDispatch::IntegrationTest
    # ERB auto-escapes `<%= %>` output, so the literal bug string
    # (`#<Company:0x...>`) never appears as raw `#<` in `response.body` --
    # it shows up HTML-entity-escaped as `#&lt;LinkingFixtures::Company:0x...&gt;`.
    # A `refute_includes response.body, "#<"` check would therefore pass
    # vacuously against the *un*fixed code. Assert on the class-name leak
    # itself instead, which survives escaping either way.
    AR_INSPECT_LEAK = "LinkingFixtures::"

    test "an index column returning an AR value links to that record's admin page" do
      get "/internal/admin_suite/ops/linking_deals"
      assert_response :success

      refute_includes response.body, AR_INSPECT_LEAK
      assert_includes response.body, "Acme Corp"
      assert_match %r{<a[^>]+href="[^"]*linking_companies/7"[^>]*>\s*Acme Corp\s*</a>}, response.body
    end

    test "an AR value with a raising display title degrades instead of 500ing the page" do
      get "/internal/admin_suite/ops/linking_deals"
      assert_response :success
      refute_includes response.body, AR_INSPECT_LEAK
    end

    test "an unpersisted AR record (to_param -> nil) renders plain text, not a broken link" do
      get "/internal/admin_suite/ops/linking_deals"
      assert_response :success
      assert_includes response.body, "Draft Vendor"
      refute_match %r{<a[^>]*>\s*Draft Vendor\s*</a>}, response.body
    end

    test "an AR value with no registered resource renders plain text, not a broken link" do
      get "/internal/admin_suite/ops/linking_deals"
      assert_response :success
      assert_includes response.body, "Ghost Vendor"
      refute_match %r{<a[^>]*>\s*Ghost Vendor\s*</a>}, response.body
    end

    test "an association table cell that is an AR value renders as a link too" do
      get "/internal/admin_suite/ops/linking_deals/1"
      assert_response :success

      refute_includes response.body, AR_INSPECT_LEAK
      assert_match %r{<a[^>]+href="[^"]*linking_companies/7"[^>]*>\s*Acme Corp\s*</a>}, response.body
      # The second line item's company has no registered resource: plain text.
      assert_includes response.body, "Ghost Vendor"
      refute_match %r{<a[^>]*>\s*Ghost Vendor\s*</a>}, response.body
    end
  end
end
