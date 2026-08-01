# frozen_string_literal: true

require "test_helper"

# Exercises `hide_blank:` on `panel`/`section` `fields:` rows. Mirrors the
# `ReadOnlyResourceFixtures::Widget` shape (test/integration/read_only_resource_test.rb)
# so the show route resolves through the ordinary numeric-id `klass.find` path,
# not the slug/uuid/token fallback.
module HideBlankFixtures
  class Widget
    extend ActiveModel::Naming

    attr_reader :id

    def initialize(id: 1)
      @id = id
    end

    def self.all
      [ new ]
    end

    def self.column_names
      %w[id]
    end

    def self.primary_key
      "id"
    end

    def self.columns_hash
      { "id" => Struct.new(:type).new(:integer) }
    end

    def self.find(id)
      raise ActiveRecord::RecordNotFound unless id.to_s == "1"

      new
    end

    def to_param
      id.to_s
    end

    def attributes
      { "id" => id }
    end

    # Non-blank control value -- always kept, hide_blank or not.
    def title
      "Widget One"
    end

    def blank_string
      ""
    end

    def whitespace_string
      "   "
    end

    def nil_field
      nil
    end

    def empty_array
      []
    end

    def empty_hash
      {}
    end

    def false_flag
      false
    end

    def zero_count
      0
    end

    def zero_float
      0.0
    end
  end
end

module Admin
  module Resources
    class HideBlankWidgetResource < Admin::Base::Resource
      model HideBlankFixtures::Widget
      portal :ops
      section :observability

      FIELDS = %i[
        title blank_string whitespace_string nil_field
        empty_array empty_hash false_flag zero_count zero_float
      ].freeze

      show do
        sidebar do
          panel :sidebar_hidden, title: "Sidebar hidden", fields: FIELDS, hide_blank: true
          panel :sidebar_default, title: "Sidebar default", fields: FIELDS
        end

        section :main_hidden, title: "Main hidden", fields: FIELDS, hide_blank: true
        section :main_default, title: "Main default", fields: FIELDS
      end
    end
  end
end

module AdminSuite
  class ShowHideBlankTest < ActionDispatch::IntegrationTest
    PATH = "/internal/admin_suite/ops/hide_blank_widgets/1"

    test "hide_blank: true hides nil, empty string, empty array, and empty hash" do
      get PATH
      assert_response :success

      hidden_section = response.body[/Main hidden.*?(?=Main default)/m]
      refute_nil hidden_section, "expected to find the 'Main hidden' panel before 'Main default' in the body"

      refute_includes hidden_section, "Nil field"
      refute_includes hidden_section, "Blank string"
      refute_includes hidden_section, "Empty array"
      refute_includes hidden_section, "Empty hash"
    end

    test "hide_blank: true keeps false, 0, 0.0, and whitespace-only strings" do
      get PATH
      assert_response :success

      hidden_section = response.body[/Main hidden.*?(?=Main default)/m]
      refute_nil hidden_section

      assert_includes hidden_section, "False flag"
      assert_includes hidden_section, "Zero count"
      assert_includes hidden_section, "Zero float"
      assert_includes hidden_section, "Whitespace string"
      # And the boolean must still render as the meaningful "No" state, not
      # silently vanish.
      assert_includes hidden_section, "No"
    end

    test "hide_blank: true keeps genuinely non-blank fields" do
      get PATH
      assert_response :success

      hidden_section = response.body[/Main hidden.*?(?=Main default)/m]
      assert_includes hidden_section, "Title"
      assert_includes hidden_section, "Widget One"
    end

    test "default (no hide_blank option) hides nothing -- every label row still renders" do
      get PATH
      assert_response :success

      default_section = response.body[/Main default.*?(?=<\/html>)/m]
      refute_nil default_section

      %w[Title Blank\ string Whitespace\ string Nil\ field Empty\ array Empty\ hash False\ flag Zero\ count Zero\ float].each do |label|
        assert_includes default_section, label, "expected label '#{label}' to render in the default (no hide_blank) panel"
      end
    end

    test "hide_blank: true on a sidebar panel hides the same blank fields as main" do
      get PATH
      assert_response :success

      sidebar_hidden = response.body[/Sidebar hidden.*?(?=Sidebar default)/m]
      refute_nil sidebar_hidden

      refute_includes sidebar_hidden, "Nil field"
      refute_includes sidebar_hidden, "Blank string"
      refute_includes sidebar_hidden, "Empty array"
      refute_includes sidebar_hidden, "Empty hash"
      assert_includes sidebar_hidden, "False flag"
      assert_includes sidebar_hidden, "Zero count"
      assert_includes sidebar_hidden, "Zero float"
    end

    test "default sidebar panel (no hide_blank) hides nothing" do
      get PATH
      assert_response :success

      sidebar_default = response.body[/Sidebar default.*?(?=<div class="bg-white)/m] || response.body[/Sidebar default.*\z/m]
      refute_nil sidebar_default

      %w[Nil\ field Blank\ string Empty\ array Empty\ hash].each do |label|
        assert_includes sidebar_default, label
      end
    end
  end
end
