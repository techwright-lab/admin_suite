# frozen_string_literal: true

require "admin_suite/ui/show_formatter_registry"

module AdminSuite
  module UI
    # Overrides `format_show_value` to use a registry of show value formatters,
    # while leaving the legacy implementation available via `super`.
    module ShowValueFormatter
      def format_show_value(record, field_name)
        value = record.public_send(field_name) rescue nil

        if (field_def = admin_suite_field_definition(field_name))
          case field_def.type
          when :markdown
            rendered =
              if defined?(::MarkdownRenderer)
                ::MarkdownRenderer.render(value.to_s)
              else
                simple_format(value.to_s)
              end
            return content_tag(:div, rendered, class: "prose dark:prose-invert max-w-none")
          when :json
            begin
              parsed =
                if value.is_a?(Hash) || value.is_a?(Array)
                  value
                elsif value.present?
                  JSON.parse(value.to_s)
                end
              return render_json_block(parsed) if parsed
            rescue JSON::ParserError
              # fall through
            end
          when :label
            return render_label_badge(value, color: field_def.label_color, size: field_def.label_size, record: record)
          end
        end

        # If the field isn't in the form config, fall back to index column config
        # so show pages can still render labels consistently.
        if respond_to?(:resource_config, true) && (rc = resource_config) && rc.index_config&.columns_list
          col = rc.index_config.columns_list.find { |c| c.name.to_sym == field_name.to_sym }
          if col&.type == :label
            label_value = col.content.is_a?(Proc) ? col.content.call(record) : value
            return render_label_badge(label_value, color: col.label_color, size: col.label_size, record: record)
          end
        end

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
