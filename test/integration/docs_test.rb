# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class DocsTest < ActionDispatch::IntegrationTest
    setup do
      @old_docs_path = AdminSuite.config.docs_path
      AdminSuite.config.docs_path = AdminSuite::Engine.root.join("test/fixtures/docs")
    end

    teardown do
      AdminSuite.config.docs_path = @old_docs_path
    end

    test "GET /internal/admin_suite/docs renders successfully" do
      get "/internal/admin_suite/docs"
      assert_response :success
      assert_includes response.body, "Documentation"
    end

    test "GET /internal/admin_suite/docs/<path> renders a markdown doc" do
      # Fixture docs live under the gem.
      get "/internal/admin_suite/docs/progress/PROGRESS_REPORT.md"
      assert_response :success

      # Should render markdown into HTML.
      assert_includes response.body, "PROGRESS REPORT"
    end

    test "docs blocks path traversal" do
      get "/internal/admin_suite/docs/../../secrets.md"
      assert_redirected_to "/internal/admin_suite/docs/"
    end

    test "docs_path config can be overridden with a proc" do
      old = AdminSuite.config.docs_path
      AdminSuite.config.docs_path = ->(_controller) { Rails.root.join("docs") }

      get "/internal/admin_suite/docs"
      assert_response :success
    ensure
      AdminSuite.config.docs_path = old
    end
  end
end
