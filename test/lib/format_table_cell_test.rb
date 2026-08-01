# frozen_string_literal: true

require "test_helper"

module AdminSuite
  # `format_table_cell` had no direct unit test anywhere in the suite before
  # this file -- it was only exercised indirectly through
  # `association_linking_test.rb`'s AR-focused fixtures. Covers the branches
  # not already pinned there, and specifically the Integer/Float/BigDecimal
  # delimiting added to match `format_show_value` (see
  # `ShowValueFormatterTest#"integers and floats render delimited"`).
  class FormatTableCellTest < ActionView::TestCase
    include AdminSuite::BaseHelper

    test "nil renders the em dash placeholder" do
      assert_equal "—", format_table_cell(nil)
    end

    test "booleans render Yes/No" do
      assert_equal "Yes", format_table_cell(true)
      assert_equal "No", format_table_cell(false)
    end

    test "Time and DateTime render a short date-time" do
      assert_equal "Jan 02, 03:04", format_table_cell(Time.utc(2026, 1, 2, 3, 4))
      assert_equal "Jan 02, 03:04", format_table_cell(DateTime.new(2026, 1, 2, 3, 4))
    end

    test "Date renders a short date" do
      assert_equal "Jan 02, 2026", format_table_cell(Date.new(2026, 1, 2))
    end

    test "integers and floats render delimited, matching format_show_value" do
      assert_equal "1,234,567", format_table_cell(1_234_567)
      assert_equal "1,234.5", format_table_cell(1234.5)
    end

    test "BigDecimal renders delimited rather than in exponential notation" do
      result = format_table_cell(BigDecimal("9876.5"))
      assert_includes result, "9,876"
      refute_includes result, "0.98765e4"
    end

    test "plain strings are truncated at 50 characters" do
      assert_equal "hello", format_table_cell("hello")
      assert_equal ("x" * 47) + "...", format_table_cell("x" * 60)
    end
  end
end
