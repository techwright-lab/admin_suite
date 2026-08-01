# frozen_string_literal: true

require "test_helper"

# A minimal ActiveModel-backed fixture with two markdown fields, registered
# as a real resource so we can render an actual /new page through the full
# stack and assert the vendored EasyMDE tags appear (not just that the files
# exist on disk, and not just that a markdown-less page omits them).
#
# Per Task 9's ledger: `Admin::Base::Resource` subclasses register into a
# process-global registry via `Class#inherited`, which fires once at class
# definition (here, at file load) and never again -- so this is safe to
# define at the top level like `ReadOnlyResourceFixtures`/`ReadOnlyWidgetResource`
# in test/integration/read_only_resource_test.rb, and doesn't interact badly
# with the nav-rebuild hazard documented there (this resource is never wiped
# or reloaded mid-run).
module LayoutAssetsFixtures
  class MarkdownWidget
    extend ActiveModel::Naming
    include ActiveModel::Conversion

    attr_accessor :id, :body, :notes

    def initialize(id: nil, body: nil, notes: nil)
      @id = id
      @body = body
      @notes = notes
    end

    def self.column_names
      %w[id body notes]
    end

    def persisted?
      !id.nil?
    end

    def new_record?
      !persisted?
    end

    # render_form_field unconditionally calls `resource.errors[field.name]`
    # (to add the error border class / message) for every field type; no
    # test here exercises a validation error, so a Hash defaulting to `[]`
    # is sufficient (same rationale as form_field_renderer_test.rb's Record).
    def errors
      Hash.new([])
    end
  end
end

module Admin
  module Resources
    class MarkdownWidgetResource < Admin::Base::Resource
      model LayoutAssetsFixtures::MarkdownWidget
      portal :ops
      section :observability

      # Two markdown fields on the same form: exercises the
      # `content_for?(:easymde_assets)` dedup guard in
      # AdminSuite::UI::FieldRendererRegistry's :markdown handler.
      form do
        field :body, type: :markdown
        field :notes, type: :markdown
      end
    end
  end
end

module AdminSuite
  class LayoutAssetsTest < ActionDispatch::IntegrationTest
    test "the admin layout requests no third-party CDN assets" do
      get "/internal/admin_suite"
      assert_response :success
      refute_includes response.body, "cdn.jsdelivr.net"
      refute_match(%r{<script[^>]+src="https?://(?!localhost)}, response.body)
    end

    test "EasyMDE ships as a vendored engine asset" do
      assert AdminSuite::Engine.root.join("app/assets/vendor/easymde.min.js").exist?
      assert AdminSuite::Engine.root.join("app/assets/vendor/easymde.min.css").exist?
    end

    test "the markdown controller bounds its editor-availability retry" do
      js = AdminSuite::Engine.root.join("app/javascript/controllers/admin_suite/markdown_editor_controller.js").read
      assert_match(/attempts|retries|maxWait/i, js)
    end

    test "a page rendering a markdown field loads the vendored EasyMDE assets, and still no CDN" do
      get "/internal/admin_suite/ops/markdown_widgets/new"
      assert_response :success

      refute_includes response.body, "cdn.jsdelivr.net"
      assert_match(%r{<link[^>]+href="[^"]*vendor/easymde\.min[^"]*\.css"}, response.body)
      assert_match(%r{<script[^>]+src="[^"]*vendor/easymde\.min[^"]*\.js"}, response.body)
    end

    test "multiple markdown fields on one form emit the EasyMDE assets exactly once" do
      get "/internal/admin_suite/ops/markdown_widgets/new"
      assert_response :success

      assert_equal 1, response.body.scan(%r{<link[^>]+href="[^"]*vendor/easymde\.min[^"]*\.css"}).size
      assert_equal 1, response.body.scan(%r{<script[^>]+src="[^"]*vendor/easymde\.min[^"]*\.js"}).size
    end

    test "a page without a markdown field never references EasyMDE" do
      get "/internal/admin_suite"
      assert_response :success
      refute_includes response.body, "vendor/easymde.min"
    end
  end
end
