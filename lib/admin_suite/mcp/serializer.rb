# frozen_string_literal: true

module AdminSuite
  module Mcp
    # Serializes only fields declared by the resource DSL. This is the MCP
    # surface's data-exposure boundary.
    module Serializer
      def self.index_row(record, config)
        config.index_config.columns_list.each_with_object({}) do |column, row|
          row[column.name] = value_for(record, column.name)
        end
      end

      def self.show_payload(record, config)
        sections = config.show_config&.sidebar_sections.to_a +
          config.show_config&.main_sections.to_a

        sections.each_with_object({}) do |section, payload|
          Array(section.fields).each do |field|
            payload[field] = value_for(record, field)
          end
        end
      end

      def self.value_for(record, name)
        return nil unless record.respond_to?(name)

        record.public_send(name)
      rescue StandardError
        nil
      end
    end
  end
end
