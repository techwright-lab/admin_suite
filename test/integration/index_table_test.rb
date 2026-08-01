# frozen_string_literal: true

require "test_helper"

# Self-contained fixtures, following the pattern established in
# association_linking_test.rb/pagination_and_stats_test.rb: this file must
# work in isolation under `rake test TEST=test/integration/index_table_test.rb`,
# so it defines everything it needs rather than depending on fixtures that
# live only in a sibling test file. `LinkingFixtures::Company` is the one
# exception -- it lives in test_helper.rb (loaded for every run) precisely
# so tasks like this one can reuse it (see test_helper.rb's comment above
# it).
module IndexTableFixtures
  # Two rows: one fully populated (including a present `belongs_to`-shaped
  # association), one deliberately sparse (nil scalar, nil association) --
  # covers item 5 (nil -> em dash) and Task 3's non-regression (a present
  # association still renders as a link) in the same fixture.
  class Widget
    extend ActiveModel::Naming

    attr_reader :id, :name, :count, :status, :company

    def initialize(id:, name:, count:, status:, company:)
      @id = id
      @name = name
      @count = count
      @status = status
      @company = company
    end

    ROWS = [
      new(id: 1, name: "Alpha", count: 5, status: "ok", company: LinkingFixtures::Company.new),
      new(id: 2, name: "Beta", count: nil, status: nil, company: nil)
    ]

    def self.all = ReadOnlyResourceFixtures::Relation.new(ROWS)
    def self.column_names = %w[id name count status]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(id) = ROWS.find { |w| w.to_param == id.to_s }
    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name, "count" => count, "status" => status }
  end

  # A real slicing relation (unlike `ReadOnlyResourceFixtures::Relation`,
  # whose `#offset`/`#limit` are no-ops returning self -- see
  # test-harness fact #8). `Pagy::Backend#pagy_get_items` calls
  # `collection.offset(pagy.offset).limit(pagy.limit)`, so this must
  # actually slice for the per-page tests to prove anything.
  class SlicingRelation
    include Enumerable

    def initialize(records, offset: 0)
      @records = records
      @offset = offset
    end

    def each(&block) = @records.each(&block)
    def count(*) = @records.length
    def offset(n) = SlicingRelation.new(@records, offset: n)
    def limit(n) = @records[@offset, n] || []
  end

  class PagedWidget
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id:) = @id = id

    ALL_ROWS = (1..150).map { |n| new(id: n) }

    def self.all = SlicingRelation.new(ALL_ROWS)
    def self.column_names = %w[id]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }
    def self.find(id) = ALL_ROWS.find { |w| w.to_param == id.to_s }
    def to_param = id.to_s
    def attributes = { "id" => id }
  end
end

module Admin
  module Resources
    class IndexTableWidgetResource < Admin::Base::Resource
      model IndexTableFixtures::Widget
      portal :ops
      section :observability

      index do
        # A filter is required for the sidebar (and thus the per-page
        # selector, which lives inside that same form) to render at all --
        # see `index.html.erb`'s `if index_config&.filters_list&.any? || ...`
        # guard.
        filters { filter :name, type: :text }
        columns do
          column :name, class: "font-mono"
          column :count, align: :right
          column :status, align: :diagonal
          column :company
        end
        paginate 10
      end
    end

    class IndexTablePagedWidgetResource < Admin::Base::Resource
      model IndexTableFixtures::PagedWidget
      portal :ops
      section :observability

      index do
        columns { column :id }
        # Deliberately distinct from the hardcoded 25 default and from any
        # of the per_page values under test (10, 50, 100), so a test that
        # asserts "10 rows" can only be passing because the DSL fallback
        # kicked in, not by coincidence with some other default.
        paginate 10
      end
    end
  end
end

module AdminSuite
  class IndexTableTest < ActionDispatch::IntegrationTest
    # Item 1: sticky header. Class-presence only -- see this task's report
    # for the CSS reasoning on whether it actually sticks inside the
    # `overflow-x-auto` wrapper.
    test "the index thead carries the sticky header classes" do
      get "/internal/admin_suite/ops/index_table_widgets"
      assert_response :success
      assert_match %r{<thead[^>]*\bsticky\b[^>]*\btop-0\b[^>]*\bz-10\b[^>]*>}, response.body
    end

    # Item 2: row click wiring, via the already-existing ClickActionsController.
    test "each row wires the click-actions controller to its own show path" do
      get "/internal/admin_suite/ops/index_table_widgets"
      assert_response :success

      assert_match(/<tr[^>]*data-controller="admin-suite--click-actions"[^>]*>/, response.body)
      # ERB HTML-escapes the `>` in the Stimulus action descriptor, so the
      # attribute renders as `click-&gt;...`, not a literal `->`.
      assert_match(/<tr[^>]*data-action="click-&gt;admin-suite--click-actions#navigate"[^>]*>/, response.body)
      assert_match(
        %r{<tr[^>]*data-admin-suite--click-actions-url-value="[^"]*index_table_widgets/1"[^>]*>},
        response.body
      )
    end

    # Item 3: per-page selector + server-side clamp.
    test "the filter form offers a 25/50/100 per_page selector" do
      get "/internal/admin_suite/ops/index_table_widgets"
      assert_response :success
      assert_match(/<select[^>]*name="per_page"[^>]*>/, response.body)
      assert_match(/<option[^>]*value="25"/, response.body)
      assert_match(/<option[^>]*value="50"/, response.body)
      assert_match(/<option[^>]*value="100"/, response.body)
    end

    # Counts `<tr>` inside `<tbody>` only, deliberately independent of item
    # 2's row-click markup (which lands in the same `<tr>` tags) -- so a
    # per_page test failure can never be secretly caused by row-click not
    # being wired yet.
    def row_count(body)
      tbody = body[%r{<tbody.*?</tbody>}m]
      tbody ? tbody.scan(/<tr[ >]/).size : 0
    end

    test "no per_page param falls back to the DSL's paginate(n) value" do
      get "/internal/admin_suite/ops/index_table_paged_widgets"
      assert_response :success
      assert_equal 10, row_count(response.body)
    end

    test "a valid per_page renders that many rows" do
      get "/internal/admin_suite/ops/index_table_paged_widgets", params: { per_page: 50 }
      assert_response :success
      assert_equal 50, row_count(response.body)
    end

    test "per_page above the max clamps to 100, not the requested amount" do
      get "/internal/admin_suite/ops/index_table_paged_widgets", params: { per_page: 999_999 }
      assert_response :success
      assert_equal 100, row_count(response.body)
    end

    test "per_page=0 falls back to the DSL value instead of an empty/unbounded page" do
      get "/internal/admin_suite/ops/index_table_paged_widgets", params: { per_page: 0 }
      assert_response :success
      assert_equal 10, row_count(response.body)
    end

    test "a negative per_page falls back to the DSL value" do
      get "/internal/admin_suite/ops/index_table_paged_widgets", params: { per_page: -1 }
      assert_response :success
      assert_equal 10, row_count(response.body)
    end

    test "a non-numeric per_page falls back to the DSL value" do
      get "/internal/admin_suite/ops/index_table_paged_widgets", params: { per_page: "abc" }
      assert_response :success
      assert_equal 10, row_count(response.body)
    end

    test "an array-shaped per_page (per_page[]=1) falls back to the DSL value" do
      get "/internal/admin_suite/ops/index_table_paged_widgets", params: { per_page: [ "1" ] }
      assert_response :success
      assert_equal 10, row_count(response.body)
    end

    # Item 4: column alignment + css_class.
    test "align: :right emits text-right on the td" do
      get "/internal/admin_suite/ops/index_table_widgets"
      assert_response :success
      assert_match(%r{<td class="[^"]*\btext-right\b[^"]*">\s*5\s*</td>}, response.body)
    end

    test "column.css_class (the class: option) reaches the td" do
      get "/internal/admin_suite/ops/index_table_widgets"
      assert_response :success
      assert_match(%r{<td class="[^"]*\bfont-mono\b[^"]*">}, response.body)
    end

    test "an unknown align value renders successfully with no fabricated text-<value> class" do
      get "/internal/admin_suite/ops/index_table_widgets"
      assert_response :success
      refute_includes response.body, "text-diagonal"
    end

    # Isolates a single fixture row's `<tr>...</tr>` markup by a distinctive
    # cell value, so nil-cell assertions can target Beta's row specifically
    # instead of matching the first empty-looking `<td>` anywhere on the
    # page (there are several: Alpha's row has none, but a loose regex
    # would not tell the two rows apart).
    def widget_row(body, marker)
      tbody = body[%r{<tbody.*?</tbody>}m]
      tbody.scan(%r{<tr.*?</tr>}m).find { |r| r.include?(marker) }
    end

    # Item 5: nil cells render an em dash, and Task 3's association links
    # are not regressed by that change.
    test "a nil scalar column renders an em dash, not a blank cell" do
      get "/internal/admin_suite/ops/index_table_widgets"
      assert_response :success
      beta_row = widget_row(response.body, "Beta")
      refute_nil beta_row, "expected to find Beta's row"
      # Beta's `count` is nil -- the fallback branch must turn that into an
      # em dash instead of the empty string it renders today.
      assert_match(%r{<td[^>]*>\s*—\s*</td>}, beta_row)
    end

    test "a nil association column renders an em dash, not a blank cell" do
      get "/internal/admin_suite/ops/index_table_widgets"
      assert_response :success
      beta_row = widget_row(response.body, "Beta")
      refute_nil beta_row, "expected to find Beta's row"
      # Beta's `company` is nil (Task 3 deliberately left nil association
      # handling to this task). Count how many dash-only cells the row has:
      # count and status are also nil, so there must be at least 3 (not 2),
      # proving company's cell got the dash too rather than staying blank.
      dash_cells = beta_row.scan(%r{<td[^>]*>\s*—\s*</td>}).size
      assert_equal 3, dash_cells,
        "expected 3 dash cells (count, status, company all nil) in Beta's row, got #{dash_cells}"
    end

    test "a present association still renders as a link (Task 3 non-regression)" do
      get "/internal/admin_suite/ops/index_table_widgets"
      assert_response :success
      assert_match %r{<a[^>]+href="[^"]*linking_companies/7"[^>]*>\s*Acme Corp\s*</a>}, response.body
    end
  end
end
