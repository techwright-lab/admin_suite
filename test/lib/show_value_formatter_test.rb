# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class ShowValueFormatterTest < ActionView::TestCase
    # ActionView::Base includes ::ERB::Util (giving views access to `h`), but
    # ActionView::TestCase::Behavior only includes ActionView::Helpers, not
    # ERB::Util. Include it here so this test's context matches what
    # BaseHelper actually runs inside at runtime (`h` is used by
    # render_text_block / highlight_json).
    include ::ERB::Util
    include AdminSuite::BaseHelper

    # A record stand-in exposing the value under the field name the formatter
    # reads via `record.public_send(field_name)`.
    Record = Struct.new(:some_field)

    def fmt(value)
      format_show_value(Record.new(value), :some_field)
    end

    test "nil renders the em dash placeholder" do
      assert_includes fmt(nil), "—"
    end

    test "booleans render Yes/No with an icon" do
      assert_includes fmt(true), "Yes"
      assert_includes fmt(false), "No"
    end

    test "dates and times render humanized with relative age" do
      assert_includes fmt(Date.new(2026, 1, 2)), "January"
      assert_includes fmt(Time.utc(2026, 1, 2, 3, 4)), "January"
      assert_includes fmt(DateTime.new(2026, 1, 2, 3, 4)), "January"
    end

    test "integers and floats render delimited" do
      assert_includes fmt(1_234_567), "1,234,567"
      assert_includes fmt(1234.5), "1,234"
    end

    test "BigDecimal renders delimited rather than as an object string" do
      result = fmt(BigDecimal("9876.5"))
      assert_includes result, "9,876"
      refute_includes result, "0.98765e4"
    end

    test "hashes render as a JSON block" do
      assert_includes fmt({ "a" => 1 }), "JSON"
    end

    test "arrays of hashes render as a JSON block" do
      assert_includes fmt([ { "a" => 1 } ]), "JSON"
    end

    test "empty arrays render a placeholder, populated arrays render chips" do
      assert_includes fmt([]), "Empty array"
      assert_includes fmt(%w[alpha beta]), "alpha"
    end

    test "long strings render as a text block, short strings render inline" do
      long = "x" * 250
      assert_includes fmt(long), "x"
      assert_includes fmt("short"), "short"
    end

    test "strings containing JSON render as a JSON block" do
      assert_includes fmt('{"mode":"fast"}'), "mode"
    end

    test "malformed JSON-looking strings fall back to plain rendering" do
      assert_includes fmt("{not actually json"), "not actually json"
    end

    test "short strings containing a newline render as a text block" do
      result = fmt("first line\nsecond line")
      assert_includes result, "bg-slate-900"
      assert_includes result, "second line"
    end

    # ActiveRecord::Base branch (show_formatter_registry.rb:72-77) is
    # untestable in this harness: the dummy app is database-free and
    # ActiveRecord::Base is never loaded/defined here, so the registry's
    # `if defined?(ActiveRecord::Base)` guard never registers that handler.
    # See task-1-report.md's fix report for the verification.
  end
end
