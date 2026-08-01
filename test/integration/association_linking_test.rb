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

  # Five deals, each pointing at a *distinct instance* of the *same*
  # `LinkingFixtures::Company` class. `auto_admin_suite_path_for`'s registry
  # lookup is keyed on `item.class`, not identity, so a correct memo
  # resolves the resource once for this whole page -- pre-memo, each of
  # the 5 rows independently re-ran the full registry scan.
  class RepeatedCompanyDeal
    extend ActiveModel::Naming

    attr_reader :id, :label, :company

    def initialize(id:, label:, company:)
      @id = id
      @label = label
      @company = company
    end

    ROWS = Array.new(5) { |i| new(id: i + 1, label: "Deal #{i + 1}", company: Company.new(id: 100 + i, name: "Company #{i + 1}")) }

    def self.all = ReadOnlyResourceFixtures::Relation.new(ROWS)
    def self.column_names = %w[id label]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(id) = all.find { |d| d.to_param == id.to_s }
    def to_param = id.to_s
    def attributes = { "id" => id, "label" => label }
  end
end

module Admin
  module Resources
    class LinkingRepeatedCompanyDealResource < Admin::Base::Resource
      model LinkingFixtures::RepeatedCompanyDeal
      portal :ops
      section :observability

      index do
        columns do
          column :label
          column :company
        end
      end
    end

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
        # `Deal.all` is a `ReadOnlyResourceFixtures::Relation` -- it has no
        # `#includes` method at all. This exercises Task 4's "skip
        # silently, don't raise" path on every request this test file
        # already makes to `/linking_deals`, not just a dedicated test.
        includes :company
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

    # Non-vacuous by construction: it counts actual invocations of
    # `ensure_admin_resources_loaded_for!` -- called exactly once per
    # registry *cache miss* inside `admin_suite_resource_for`, and nowhere
    # else in the gem. (A page-wide spy on
    # `Admin::Base::Resource.registered_resources` itself was tried first
    # and rejected: navigation building calls it many more times per
    # request for unrelated reasons -- e.g. `resources_for_portal` -- so
    # that count is dominated by noise this task didn't touch.)
    #
    # Pre-memo, `auto_admin_suite_path_for` called
    # `ensure_admin_resources_loaded_for!(item.class)` unconditionally on
    # every invocation -- 5 rows of the same class meant 5 calls (and 2
    # full registry scans apiece: the `.any?` inside it, plus the
    # `registered_resources.find` right after). Memoized, only the first
    # row's lookup is a cache miss; the other 4 hit
    # `@admin_suite_resource_for` and never call this method at all -- so
    # the call count for 5 rows must be 1, not 5. A test that only
    # asserted "the memo hash is non-empty" would still pass if the memo
    # were consulted but the scan ran unconditionally anyway; this asserts
    # the scan was actually skipped.
    test "auto_admin_suite_path_for memoizes the registry lookup per class, not per row" do
      call_count = 0
      helper_module = AdminSuite::BaseHelper
      original_method = helper_module.instance_method(:ensure_admin_resources_loaded_for!)

      helper_module.send(:define_method, :ensure_admin_resources_loaded_for!) do |model_class|
        call_count += 1
        original_method.bind(self).call(model_class)
      end

      begin
        get "/internal/admin_suite/ops/linking_repeated_company_deals"
        assert_response :success
        assert_includes response.body, "Company 1"
        assert_includes response.body, "Company 5"
      ensure
        helper_module.send(:define_method, :ensure_admin_resources_loaded_for!, original_method)
      end

      assert_equal 1, call_count,
        "expected exactly one registry lookup for 5 rows of the same class (LinkingFixtures::Company) " \
        "-- got #{call_count}, which means the memo isn't preventing a rescan per row"
    end
  end
end
