# frozen_string_literal: true

require "json_schemer"

module Signals
  module Contracts
    module Validators
      # Validates JSON objects against Draft 2020-12 JSON Schemas.
      #
      # Schemas in this repo use stable `$id` URIs like:
      #   gleania://signals/contracts/schemas/decision_input.schema.json
      #
      # This validator resolves those `$ref`s to files under:
      #   app/domains/signals/contracts/schemas/
      class JsonSchemaValidator
        SCHEMA_ID_PREFIX = "gleania://signals/contracts/schemas/".freeze

        def initialize(schema_id:)
          @schema_id = schema_id
        end

        def valid?(data)
          errors_for(data).empty?
        end

        # @return [Array<Hash>] json_schemer error hashes
        def errors_for(data)
          schemer.validate(data).to_a
        end

        private

        attr_reader :schema_id

        def schemer
          @schemer ||= JSONSchemer.schema(root_schema_json, ref_resolver: method(:resolve_ref))
        end

        def root_schema_json
          JSON.parse(File.read(path_for_schema_id(schema_id)))
        end

        # Resolve `$ref` schema IDs (gleania://...) to local files.
        def resolve_ref(uri)
          uri_str = uri.to_s
          base_uri = uri_str.split("#", 2).first
          return nil unless base_uri.start_with?(SCHEMA_ID_PREFIX)

          path = path_for_schema_id(base_uri)
          JSON.parse(File.read(path))
        end

        def path_for_schema_id(uri)
          raise ArgumentError, "Unsupported schema id: #{uri}" unless uri.start_with?(SCHEMA_ID_PREFIX)

          relative = uri.delete_prefix(SCHEMA_ID_PREFIX)
          File.join(Rails.root, "app/domains/signals/contracts/schemas", relative)
        end
      end
    end
  end
end
