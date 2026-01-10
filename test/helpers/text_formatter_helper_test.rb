# frozen_string_literal: true

require "test_helper"

class TextFormatterHelperTest < ActionView::TestCase
  include TextFormatterHelper

  test "format_job_text decodes escaped HTML entities and renders sanitized HTML" do
    input = "&lt;p&gt;&lt;strong&gt;Hello&lt;/strong&gt; world&lt;/p&gt;"
    output = format_job_text(input)

    assert_includes output, "<p"
    assert_includes output, "<strong"
    assert_includes output, "Hello"
    assert_not_includes output, "&lt;p&gt;"
  end

  test "format_job_text markdown preserves inline strong tags (sanitized) and renders horizontal rules" do
    input = <<~MD
      - <strong>Minimum salary:</strong> $5,000 USD per month

      ---

      > Note: This is a test
    MD

    output = format_job_text(input)

    assert_includes output, "<strong>"
    assert_includes output, "<hr"
    assert_includes output, "<blockquote"
  end
end
