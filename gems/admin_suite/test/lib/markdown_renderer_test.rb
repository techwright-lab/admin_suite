# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class MarkdownRendererTest < ActiveSupport::TestCase
    test "renders html and extracts toc from headings" do
      md = <<~MD
        ## Section

        Hello world
      MD

      result = AdminSuite::MarkdownRenderer.new(md).render
      assert_includes result[:html].to_s, "<h2"
      assert_equal 1, result[:reading_time_minutes]
      assert_equal [ { level: 2, id: "section", text: "Section" } ], result[:toc]
    end
  end
end
