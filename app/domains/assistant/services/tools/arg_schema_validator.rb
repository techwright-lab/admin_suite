# frozen_string_literal: true

module Assistant
  module Tools
    # Minimal JSON-schema-like validator for tool args.
    #
    # Supported schema keys:
    # - type: "object"
    # - required: ["field1", ...]
    # - properties: { "field" => { "type" => "string|integer|boolean|number|object|array" } }
    #
    # Intentionally minimal to avoid new dependencies.
    class ArgSchemaValidator
      def initialize(schema)
        @schema = schema.is_a?(Hash) ? schema : {}
      end

      def validate(args)
        args = args.is_a?(Hash) ? args : {}
        return [] if schema.blank?

        # Support top-level anyOf/oneOf (minimal): valid if any sub-schema validates.
        branches = Array(schema["anyOf"] || schema[:anyOf] || schema["oneOf"] || schema[:oneOf])
        if branches.any?
          branch_errors = branches.map { |sub| self.class.new(sub).validate(args) }
          return [] if branch_errors.any?(&:empty?)
          # Fall through and report errors from the first branch + base schema requirements/types.
        end

        errors = []
        errors.concat(validate_required(args))
        errors.concat(validate_types(args))
        errors
      end

      private

      attr_reader :schema

      def validate_required(args)
        required = Array(schema["required"] || schema[:required])
        required.filter_map do |key|
          k = key.to_s
          "#{k} is required" if args[k].nil? && args[key.to_sym].nil?
        end
      end

      def validate_types(args)
        props = schema["properties"] || schema[:properties]
        return [] unless props.is_a?(Hash)

        props.flat_map do |k, v|
          expected = (v.is_a?(Hash) ? (v["type"] || v[:type]) : nil)
          next [] if expected.blank?

          val = args[k.to_s]
          val = args[k.to_sym] if val.nil?
          next [] if val.nil?

          ok = case expected.to_s
          when "string" then val.is_a?(String)
          when "integer" then val.is_a?(Integer)
          when "number" then val.is_a?(Numeric)
          when "boolean" then val == true || val == false
          when "object" then val.is_a?(Hash)
          when "array" then val.is_a?(Array)
          else true
          end

          ok ? [] : [ "#{k} must be a #{expected}" ]
        end
      end
    end
  end
end
