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
          when :toggle
            return render_show_toggle(record, field_def.name)
          when :markdown
            rendered =
              if defined?(::MarkdownRenderer)
                ::MarkdownRenderer.render(value.to_s)
              else
                simple_format(value.to_s)
              end
            return content_tag(:div, rendered, class: "prose max-w-none")
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
          col = rc.index_config.columns_list.find do |c|
            c.name.to_sym == field_name.to_sym || c.toggle_field&.to_sym == field_name.to_sym
          end
          if col&.type == :toggle
            toggle_field = (col.toggle_field || col.name).to_sym
            return render_show_toggle(record, toggle_field)
          elsif col&.type == :label
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

      private

      def render_show_toggle(record, field)
        toggle_url =
          begin
            resource_toggle_path(
              portal: current_portal,
              resource_name: resource_name,
              id: record.to_param,
              field: field
            )
          rescue StandardError
            nil
          end

        render(
          partial: "admin_suite/shared/toggle_cell",
          locals: { record: record, field: field, toggle_url: toggle_url }
        )
      end
    end
  end
end
