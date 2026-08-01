# frozen_string_literal: true

require "test_helper"

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
  end
end
