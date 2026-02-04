# frozen_string_literal: true

require "admin_suite/ui/show_formatter_registry"

module AdminSuite
  module UI
    # Overrides `format_show_value` to use a registry of show value formatters,
    # while leaving the legacy implementation available via `super`.
    module ShowValueFormatter
      def format_show_value(record, field_name)
        value = record.public_send(field_name) rescue nil

        if value.is_a?(ActiveStorage::Attached::One)
          return render_attachment_preview(value)
        elsif value.is_a?(ActiveStorage::Attached::Many)
          return render_attachments_preview(value)
        end

        formatted =
          AdminSuite::UI::ShowFormatterRegistry.format(
            value,
            view: self,
            record: record,
            field_name: field_name
          )

        return formatted unless formatted.nil?

        super
      end
    end
  end
end
