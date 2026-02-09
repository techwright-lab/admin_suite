# frozen_string_literal: true

module AdminSuite
  module UI
    module FieldRendererRegistry
      class << self
        def handlers
          @handlers ||= {}
        end

        def register(type, &block)
          handlers[type.to_sym] = block
        end

        def render(type, view:, f:, field:, resource:, field_class:)
          handler = handlers[type.to_sym]
          return nil unless handler

          handler.call(view, f, field, resource, field_class)
        end
      end
    end
  end
end

# ---- default field renderers ----
AdminSuite::UI::FieldRendererRegistry.register(:textarea) do |_view, f, field, resource, field_class|
  f.text_area(field.name, class: field_class, rows: field.rows || 4, placeholder: field.placeholder, readonly: field.readonly)
end

AdminSuite::UI::FieldRendererRegistry.register(:url) do |_view, f, field, resource, field_class|
  f.url_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
end

AdminSuite::UI::FieldRendererRegistry.register(:email) do |_view, f, field, resource, field_class|
  f.email_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
end

AdminSuite::UI::FieldRendererRegistry.register(:number) do |_view, f, field, resource, field_class|
  f.number_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
end

AdminSuite::UI::FieldRendererRegistry.register(:toggle) do |view, f, field, resource, _field_class|
  view.render_toggle_field(f, field, resource)
end

AdminSuite::UI::FieldRendererRegistry.register(:label) do |view, _f, field, resource, _field_class|
  label_value = resource.public_send(field.name) rescue nil
  view.render_label_badge(label_value, color: field.label_color, size: field.label_size, record: resource)
end

AdminSuite::UI::FieldRendererRegistry.register(:select) do |_view, f, field, resource, field_class|
  collection = field.collection.is_a?(Proc) ? field.collection.call : field.collection
  f.select(field.name, collection, { include_blank: true }, class: field_class, disabled: field.readonly)
end

AdminSuite::UI::FieldRendererRegistry.register(:searchable_select) do |view, f, field, resource, _field_class|
  view.render_searchable_select(f, field, resource)
end

AdminSuite::UI::FieldRendererRegistry.register(:multi_select) do |view, f, field, resource, _field_class|
  view.render_multi_select(f, field, resource)
end

AdminSuite::UI::FieldRendererRegistry.register(:tags) do |view, f, field, resource, _field_class|
  view.render_multi_select(f, field, resource)
end

AdminSuite::UI::FieldRendererRegistry.register(:image) do |view, f, field, resource, _field_class|
  view.render_file_upload(f, field, resource)
end

AdminSuite::UI::FieldRendererRegistry.register(:attachment) do |view, f, field, resource, _field_class|
  view.render_file_upload(f, field, resource)
end

AdminSuite::UI::FieldRendererRegistry.register(:trix) do |_view, f, field, resource, _field_class|
  f.rich_text_area(field.name, class: "prose max-w-none")
end

AdminSuite::UI::FieldRendererRegistry.register(:rich_text) do |_view, f, field, resource, _field_class|
  f.rich_text_area(field.name, class: "prose max-w-none")
end

AdminSuite::UI::FieldRendererRegistry.register(:markdown) do |_view, f, field, resource, field_class|
  f.text_area(field.name, class: "#{field_class} font-mono", rows: field.rows || 12, data: { controller: "admin-suite--markdown-editor" }, placeholder: field.placeholder)
end

AdminSuite::UI::FieldRendererRegistry.register(:file) do |_view, f, field, resource, _field_class|
  f.file_field(field.name, class: "form-input-file", accept: field.accept)
end

AdminSuite::UI::FieldRendererRegistry.register(:datetime) do |_view, f, field, resource, field_class|
  f.datetime_local_field(field.name, class: field_class, readonly: field.readonly)
end

AdminSuite::UI::FieldRendererRegistry.register(:date) do |_view, f, field, resource, field_class|
  f.date_field(field.name, class: field_class, readonly: field.readonly)
end

AdminSuite::UI::FieldRendererRegistry.register(:time) do |_view, f, field, resource, field_class|
  f.time_field(field.name, class: field_class, readonly: field.readonly)
end

AdminSuite::UI::FieldRendererRegistry.register(:json) do |view, f, field, resource, _field_class|
  view.render("admin_suite/shared/json_editor_field", f: f, field: field, resource: resource)
end

AdminSuite::UI::FieldRendererRegistry.register(:code) do |view, f, field, resource, _field_class|
  view.render_code_editor(f, field, resource)
end

AdminSuite::UI::FieldRendererRegistry.register(:text) do |_view, f, field, resource, field_class|
  f.text_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
end

AdminSuite::UI::FieldRendererRegistry.register(:string) do |_view, f, field, resource, field_class|
  f.text_field(field.name, class: field_class, placeholder: field.placeholder, readonly: field.readonly)
end
