# frozen_string_literal: true

module AdminSuite
  module ResourcesHelper
    # Renders a column value from a record.
    #
    # @param record [ActiveRecord::Base]
    # @param column [Admin::Base::Resource::ColumnDefinition]
    # @return [String]
    def render_column_value(record, column)
      if column.content.is_a?(Proc)
        column.content.call(record)
      else
        record.public_send(column.name) rescue "—"
      end
    end

    # Formats a value for display on show pages.
    #
    # @param record [ActiveRecord::Base]
    # @param field_name [Symbol, String]
    # @return [String]
    def format_show_value(record, field_name)
      value = record.public_send(field_name) rescue nil

      case value
      when nil then "—"
      when true then "Yes"
      when false then "No"
      when Time, DateTime then value.strftime("%b %d, %Y %H:%M")
      when Date then value.strftime("%b %d, %Y")
      else value.to_s
      end
    end
  end
end
