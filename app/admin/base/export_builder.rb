# frozen_string_literal: true

require "csv"

module Admin
  module Base
    # Builds export data for admin resources
    #
    # Generates JSON or CSV exports based on resource configuration
    # and the columns defined in the index configuration.
    #
    # @example
    #   export_builder = Admin::Base::ExportBuilder.new(CompanyResource, companies)
    #   json_data = export_builder.to_json
    #   csv_data = export_builder.to_csv
    class ExportBuilder
      attr_reader :resource_class, :records

      # Initializes the export builder
      #
      # @param resource_class [Class] The resource class
      # @param records [ActiveRecord::Relation, Array] Records to export
      def initialize(resource_class, records)
        @resource_class = resource_class
        @records = records
      end

      # Exports records to JSON
      #
      # @param options [Hash] Export options
      # @option options [Boolean] :pretty Pretty print JSON
      # @return [String] JSON string
      def to_json(options = {})
        data = records.map { |record| record_to_hash(record) }

        if options[:pretty]
          JSON.pretty_generate(export_wrapper(data))
        else
          export_wrapper(data).to_json
        end
      end

      # Exports records to CSV
      #
      # @return [String] CSV string
      def to_csv
        return "" if records.empty?

        headers = export_columns.map { |col| col[:header] }

        CSV.generate do |csv|
          csv << headers

          records.each do |record|
            csv << export_columns.map { |col| column_value(record, col) }
          end
        end
      end

      # Returns the filename for export
      #
      # @param format [Symbol] Export format (:json, :csv)
      # @return [String]
      def filename(format)
        timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
        "#{resource_class.resource_name_plural}_#{timestamp}.#{format}"
      end

      # Returns content type for export
      #
      # @param format [Symbol] Export format
      # @return [String]
      def content_type(format)
        case format.to_sym
        when :json
          "application/json"
        when :csv
          "text/csv"
        else
          "application/octet-stream"
        end
      end

      private

      def index_config
        @resource_class.index_config
      end

      def model_class
        @resource_class.model_class
      end

      def export_wrapper(data)
        {
          resource: resource_class.resource_name,
          exported_at: Time.current.iso8601,
          count: data.length,
          records: data
        }
      end

      def export_columns
        return default_columns unless index_config

        columns = index_config.columns_list.map do |col|
          {
            name: col.name,
            header: col.header,
            content: col.content
          }
        end

        # Add id and timestamps if not already present
        unless columns.any? { |c| c[:name] == :id }
          columns.unshift({ name: :id, header: "ID", content: nil })
        end

        unless columns.any? { |c| c[:name] == :created_at }
          columns << { name: :created_at, header: "Created At", content: nil }
        end

        columns
      end

      def default_columns
        model_class.column_names.map do |col|
          { name: col.to_sym, header: col.humanize, content: nil }
        end
      end

      def record_to_hash(record)
        hash = {}

        export_columns.each do |col|
          hash[col[:name]] = column_value(record, col)
        end

        hash
      end

      def column_value(record, col)
        if col[:content].is_a?(Proc)
          value = col[:content].call(record)
        elsif col[:content].is_a?(Symbol)
          value = record.public_send(col[:content])
        elsif record.respond_to?(col[:name])
          value = record.public_send(col[:name])
        else
          value = nil
        end

        # Serialize complex values for export
        serialize_value(value)
      end

      def serialize_value(value)
        case value
        when ActiveRecord::Base
          value.id
        when ActiveRecord::Relation
          value.pluck(:id)
        when Time, DateTime
          value.iso8601
        when Date
          value.to_s
        when Hash, Array
          value
        else
          value.to_s
        end
      end
    end
  end
end

