# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class ThemePaletteTest < ActiveSupport::TestCase
    test "resolve returns hex for known palette entries" do
      assert_equal "#4f46e5", AdminSuite::ThemePalette.resolve("indigo", 600)
      assert_equal "#581c87", AdminSuite::ThemePalette.resolve("purple", 900)
    end

    test "resolve returns fallback for unknown color/shade" do
      assert_equal "#000000", AdminSuite::ThemePalette.resolve("unknown", 600, fallback: "#000000")
      assert_nil AdminSuite::ThemePalette.resolve("unknown", 600)
    end

    test "hex? validates hex colors" do
      assert AdminSuite::ThemePalette.hex?("#fff")
      assert AdminSuite::ThemePalette.hex?("#a1b2c3")
      refute AdminSuite::ThemePalette.hex?("indigo")
      refute AdminSuite::ThemePalette.hex?(nil)
    end
  end
end
