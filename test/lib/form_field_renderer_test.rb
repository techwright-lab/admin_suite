# frozen_string_literal: true

require "test_helper"

module AdminSuite
  class FormFieldRendererTest < ActionView::TestCase
    include AdminSuite::BaseHelper

    Record = Struct.new(:name, :body, :enabled, :error_messages) do
      # Both a class-level and an instance-level `model_name` are needed:
      # `render_toggle_field`/`render_searchable_select`/`render_multi_select`
      # all call `resource.class.model_name.param_key` (class-level), while
      # `form_with` itself wants the instance-level accessor. (`extend
      # ActiveModel::Naming` would give both via its own delegation, but
      # then redefining `model_name` below to force the short "Record" name
      # -- rather than the fully-qualified nested constant name -- clashes
      # with that delegation and triggers a "method redefined" warning.
      # Defining both explicitly avoids it.) The pre-existing instance-level
      # `model_name` never covered the class-level call site because no test
      # here exercised `:toggle`/`:searchable_select`/`:multi_select` before.
      def self.model_name
        @model_name ||= ActiveModel::Name.new(self, nil, "Record")
      end

      def to_model = self
      def model_name = self.class.model_name
      def persisted? = false
      def to_key = nil

      # render_form_field unconditionally calls `resource.errors[field.name]`
      # for every field type (to add the error border class / message), so
      # the double needs an `errors` object supporting `[]` -> Array-like
      # (`.any?`, `.first`). Most tests here don't exercise an actual
      # validation error, so a Hash defaulting to `[]` is sufficient; tests
      # that do pass `error_messages` (a plain Hash of field name -> Array of
      # messages) to get real per-field errors without losing the default.
      def errors
        Hash.new([]).merge(error_messages || {})
      end
    end

    def field(name, type, **overrides)
      Admin::Base::Resource::FieldDefinition.new(
        {
          name: name, type: type, required: false, label: name.to_s.humanize,
          readonly: false, multiple: false, creatable: false, preview: true
        }.merge(overrides)
      )
    end

    def render_field(type, name: :name, error_messages: nil, **field_overrides)
      record = Record.new("x", "y", true, error_messages)
      html = nil
      form_with(model: record, url: "/", scope: :record) { |f| html = render_form_field(f, field(name, type, **field_overrides), record) }
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

    test "a field with a validation error renders the red border and error message" do
      html = render_field(:text, error_messages: { name: [ "is invalid" ] })
      assert_includes html, "border-red-500"
      assert_includes html, "is invalid"
    end

    # Table-driven, iterating the registry itself (not a hardcoded list) so
    # deleting a registration is caught here even if nothing else in the
    # suite happens to exercise that type. Before this test, 17 of 24
    # registered field types were entirely unpinned.
    test "every registered field type renders non-empty markup" do
      sample_collection = [ [ "One", 1 ], [ "Two", 2 ] ]
      needs_collection = %i[select searchable_select dependent_select multi_select tags]

      # :trix/:rich_text both call `f.rich_text_area`, which only exists
      # once ActionText's FormBuilder extension is loaded -- and per the
      # plan's Test-harness fact #2, this dummy app is deliberately
      # database-free and never requires `action_text/engine`. Confirmed by
      # running this test with them included: `NoMethodError: undefined
      # method 'rich_text_area'`, not a bug in FieldRendererRegistry. There
      # is no way to pin these two types in this harness without pulling in
      # ActionText (and, transitively, ActiveRecord) — out of scope here.
      untestable_without_action_text = %i[trix rich_text]

      AdminSuite::UI::FieldRendererRegistry.handlers.keys.each do |type|
        next if untestable_without_action_text.include?(type)

        overrides = needs_collection.include?(type) ? { collection: sample_collection } : {}
        html = render_field(type, **overrides)
        assert html.present?, "expected #{type.inspect} to render non-empty markup"
      end
    end
  end
end
