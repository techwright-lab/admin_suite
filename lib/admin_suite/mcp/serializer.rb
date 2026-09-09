# frozen_string_literal: true

module AdminSuite
  module Mcp
    # Serializes only fields declared by the resource DSL. This is the MCP
    # surface's data-exposure boundary.
    module Serializer
      def self.index_row(record, config)
        config.index_config.columns_list.each_with_object({}) do |column, row|
          row[column.name] = primitive(resolve_column(record, column))
        end
      end

      def self.show_payload(record, config)
        sections = config.show_config&.sidebar_sections.to_a +
          config.show_config&.main_sections.to_a

        sections.each_with_object({}) do |section, payload|
          Array(section.fields).each do |field|
            payload[field] = primitive(value_for(record, field))
          end
        end
      end

      def self.associations_payload(record, config, max_rows:)
        sections = config.show_config&.sidebar_sections.to_a + config.show_config&.main_sections.to_a
        sections.each_with_object({}) do |section, payload|
          next if section.association.blank? || section.columns.blank?

          payload[section.name] = association_panel(record, section, max_rows)
        end
      end

      def self.dump(payload)
        JSON.pretty_generate(primitive(payload))
      end

      def self.resolve_column(record, column)
        if column.respond_to?(:type) && column.type == :toggle
          field = column.respond_to?(:toggle_field) ? (column.toggle_field || column.name) : column.name
          value_for(record, field)
        elsif column.respond_to?(:type) && column.type == :label
          proc_or_attribute(record, column)
        elsif column.respond_to?(:content) && column.content.is_a?(Proc)
          column.content.call(record)
        else
          value_for(record, column.name)
        end
      rescue StandardError
        nil
      end
      private_class_method :resolve_column

      def self.proc_or_attribute(record, column)
        if column.respond_to?(:content) && column.content.is_a?(Proc)
          column.content.call(record)
        else
          value_for(record, column.name)
        end
      end
      private_class_method :proc_or_attribute

      def self.association_panel(record, section, max_rows)
        limit = Integer(section.limit || section.per_page || max_rows).clamp(1..max_rows)
        rows = record.public_send(section.association)
        rows = rows.respond_to?(:limit) ? rows.limit(limit) : Array(rows).first(limit)
        {
          applied_limit: limit,
          rows: Array(rows).map do |row|
            section.columns.to_h { |column| [ column, primitive(value_for(row, column)) ] }
          end
        }
      rescue StandardError
        { applied_limit: 0, rows: [] }
      end
      private_class_method :association_panel

      def self.value_for(record, name)
        return nil unless record.respond_to?(name)

        record.public_send(name)
      rescue StandardError
        nil
      end
      private_class_method :value_for

      def self.primitive(value)
        case value
        when nil, true, false, String, Integer, Float
          value
        when Symbol
          value.to_s
        when Date, Time, DateTime
          value.iso8601
        when Array
          value.map { |item| primitive(item) }
        when Hash
          value.each_with_object({}) { |(key, item), acc| acc[key] = primitive(item) }
        else
          coerce_object(value)
        end
      rescue StandardError
        nil
      end
      private_class_method :primitive

      def self.coerce_object(value)
        if defined?(ActiveSupport::TimeWithZone) && value.is_a?(ActiveSupport::TimeWithZone)
          value.iso8601
        elsif defined?(BigDecimal) && value.is_a?(BigDecimal)
          value.to_s("F")
        elsif defined?(ActiveRecord::Base) && value.is_a?(ActiveRecord::Base)
          display_name(value)
        elsif value.respond_to?(:iso8601)
          value.iso8601
        else
          display_name(value)
        end
      end
      private_class_method :coerce_object

      def self.display_name(item)
        %i[name title display_title].each do |method_name|
          next unless item.respond_to?(method_name)

          text = item.public_send(method_name)
          return text.to_s if text.present?
        end
        return "##{item.id}" if item.respond_to?(:id) && !item.id.nil?

        item.class.name
      rescue StandardError
        nil
      end
      private_class_method :display_name
    end
  end
end
