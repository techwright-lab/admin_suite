# frozen_string_literal: true

require "admin_suite/ui/field_renderer_registry"

module AdminSuite
  module UI
    # Implements `render_form_field` using a registry of field renderers.
    module FormFieldRenderer
      def render_form_field(f, field, resource)
        return if field.if_condition.present? && !field.if_condition.call(resource)
        return if field.unless_condition.present? && field.unless_condition.call(resource)

        capture do
          concat(content_tag(:div, class: "form-group") do
            concat(f.label(field.name, class: "form-label") do
              concat(field.label)
              concat(content_tag(:span, " *", class: "text-red-500")) if field.required
            end)

            field_class = "form-input w-full"
            field_class += " border-red-500" if resource.errors[field.name].any?

            field_html =
              AdminSuite::UI::FieldRendererRegistry.render(
                field.type || :text,
                view: self,
                f: f,
                field: field,
                resource: resource,
                field_class: field_class
              )

            concat(field_html)

            concat(content_tag(:p, field.help, class: "mt-1 text-sm text-slate-500")) if field.help.present?
            concat(content_tag(:p, resource.errors[field.name].first, class: "mt-1 text-sm text-red-600")) if resource.errors[field.name].any?
          end)
        end
      end
    end
  end
end
