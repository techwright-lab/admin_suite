# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class FormFieldRendererTest < ActionView::TestCase
    include AdminSuite::BaseHelper

    Record = Struct.new(:name, :body, :enabled) do
      def to_model = self
      def model_name = ActiveModel::Name.new(self.class, nil, "Record")
      def persisted? = false
      def to_key = nil

      # render_form_field unconditionally calls `resource.errors[field.name]`
      # for every field type (to add the error border class / message), so
      # the double needs an `errors` object supporting `[]` -> Array-like
      # (`.any?`, `.first`). No test here exercises an actual validation
      # error, so a Hash defaulting to `[]` is sufficient.
      def errors = Hash.new([])
    end

    def field(name, type)
      Admin::Base::Resource::FieldDefinition.new(
        name: name, type: type, required: false, label: name.to_s.humanize,
        readonly: false, multiple: false, creatable: false, preview: true
      )
    end

    def render_field(type, name: :name)
      record = Record.new("x", "y", true)
      html = nil
      form_with(model: record, url: "/", scope: :record) { |f| html = render_form_field(f, field(name, type), record) }
      html.to_s
    end

    test "textarea type renders a textarea" do
      assert_includes render_field(:textarea, name: :body), "<textarea"
    end

    test "email and url types render matching inputs" do
      assert_includes render_field(:email), 'type="email"'
      assert_includes render_field(:url), 'type="url"'
    end

    test "date and datetime types render matching inputs" do
      assert_includes render_field(:date), 'type="date"'
      assert_includes render_field(:datetime), 'type="datetime-local"'
    end

    test "markdown type wires the markdown editor controller" do
      assert_includes render_field(:markdown, name: :body), "admin-suite--markdown-editor"
    end

    test "an unregistered type falls back to a text field" do
      html = render_field(:totally_unknown_type)
      assert_includes html, 'type="text"'
    end

    test "the label is rendered for every field" do
      assert_includes render_field(:text), "Name"
    end
  end
end
