# frozen_string_literal: true

require "test_helper"

# Self-contained fixture, following the pattern established in
# authorization_test.rb/read_only_resource_test.rb: each integration test
# file defines its own model + resource rather than depending on another
# test file's fixture being loaded. Rake's TEST= support (rake/testtask.rb)
# replaces the whole file list with just the one file requested, so a
# fixture defined only in a sibling test file (e.g. ReadOnlyWidgetResource
# in read_only_resource_test.rb) does not exist when this file is run in
# isolation with `rake test TEST=test/integration/pagination_and_stats_test.rb`
# (the exact command this task's brief calls for) — that dependency was a
# plan-authored test defect, fixed here rather than in the implementation.
module PaginationStatsFixtures
  class Widget
    extend ActiveModel::Naming

    attr_reader :id, :name

    def initialize(id: 1, name: "Observed widget")
      @id = id
      @name = name
    end

    def self.all = ReadOnlyResourceFixtures::Relation.new((1..25).map { |n| new(id: n, name: "Observed widget #{n}") })
    def self.column_names = %w[id name]
    def self.primary_key = "id"
    def self.columns_hash = { "id" => Struct.new(:type).new(:integer) }

    def self.find(id)
      raise ActiveRecord::RecordNotFound unless id.to_s == "1"

      new
    end

    def to_param = id.to_s
    def attributes = { "id" => id, "name" => name }

    # A plain Array, not ReadOnlyResourceFixtures::Relation: render_association_section
    # slices it via `Array.wrap(associated)[pagy.offset, per_page]` (the
    # branch taken when the association doesn't respond to :offset), which
    # exercises real pagination slicing rather than the Relation stand-in's
    # no-op #offset/#limit.
    def parts
      (1..5).map { |n| Part.new(n) }
    end
  end

  # Plain (non-ActiveRecord) associated record: exercises
  # render_association_section's pagination path, the sole surviving caller
  # of the deleted pagy_prev_link/pagy_next_link/pagy_page_links/
  # render_pagy_series_item/render_association_pagination helpers.
  class Part
    attr_reader :id, :name

    def initialize(id)
      @id = id
      @name = "Part #{id}"
    end
  end
end

module Admin
  module Resources
    class PaginationStatsWidgetResource < Admin::Base::Resource
      model PaginationStatsFixtures::Widget
      portal :ops
      section :observability
      read_only

      index do
        columns { column :name }
        paginate 10
        stats do
          stat :total, -> { 7 }, color: :indigo
        end
      end

      show do
        section :parts, association: :parts, paginate: true, per_page: 2
      end
    end
  end
end

module AdminSuite
  class PaginationAndStatsTest < ActionDispatch::IntegrationTest
    test "index stats render without dynamic tailwind color classes" do
      get "/internal/admin_suite/ops/pagination_stats_widgets"
      assert_response :success
      refute_match(/class="[^"]*text-\{/, response.body)
      # A real stat, with a real (new) color, rendered end to end through
      # AdminSuite::UI::PanelDefinition + admin_suite/panels/_stat — not
      # just a source-text check that the dynamic interpolation is gone.
      assert_includes response.body, "text-indigo-700"
      assert_includes response.body, ">7<"
    end

    test "the index stats markup comes from the shared stat partial" do
      source = AdminSuite::Engine.root.join("app/views/admin_suite/resources/index.html.erb").read
      refute_includes source, 'text-<%= color %>-600'
      assert_includes source, "admin_suite/panels/stat"
    end

    test "pagination markup is a single shared partial" do
      index = AdminSuite::Engine.root.join("app/views/admin_suite/resources/index.html.erb").read
      helper = AdminSuite::Engine.root.join("app/helpers/admin_suite/base_helper.rb").read
      assert_includes index, "admin_suite/shared/pagination"
      refute_includes helper, "def pagy_prev_link"
      refute_includes helper, "def render_pagy_series_item"
    end

    # The brief's original version of this test rendered the partial in
    # isolation via `ApplicationController.render(partial:, locals:)`. That
    # bare renderer has no routed request, so `params` carries no
    # :controller/:action, and the partial's `url_for(params.permit!.merge(...))`
    # calls (verbatim from the index view, per the brief's Step 3) raise
    # `ActionController::UrlGenerationError: No route matches`. That is a
    # second plan-authored test defect: fixed here by exercising the partial
    # through a real routed request, which is how both callers (index,
    # association panels) actually invoke it.
    test "the shared pagination partial renders prev, next and the series" do
      get "/internal/admin_suite/ops/pagination_stats_widgets", params: { page: 2 }
      assert_response :success
      assert_includes response.body, "Prev"
      assert_includes response.body, "Next"
      assert_includes response.body, "3"
    end

    test "association panel pagination renders through the same shared partial" do
      get "/internal/admin_suite/ops/pagination_stats_widgets/1", params: { parts_page: 2 }
      assert_response :success
      assert_includes response.body, "Prev"
      assert_includes response.body, "Next"
      # Richer, index-derived markup that render_association_pagination
      # (now deleted) never rendered: the "Showing X to Y of Z results"
      # summary line (5 parts, 2 per page, page 2 => items 3-4).
      assert_includes response.body, "Showing"
      assert_includes response.body, "results"
      assert_includes response.body, "3"
      assert_includes response.body, "4"
      assert_includes response.body, "5"
      # The part most likely to regress: the per-association page param
      # (association_page_param -> "#{section.association}_page"), not the
      # generic :page the index uses.
      assert_includes response.body, "parts_page=1"
      assert_includes response.body, "parts_page=3"
      refute_includes response.body, "?page=1"
    end
  end
end
