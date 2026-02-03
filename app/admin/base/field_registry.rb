# frozen_string_literal: true

module Admin
  module Base
    # Registry for form field types
    #
    # Maps field types to their corresponding view partials and
    # provides helper methods for rendering fields based on their type.
    #
    # @example
    #   registry = Admin::Base::FieldRegistry.new
    #   partial = registry.partial_for(:toggle)
    #   # => "admin/fields/toggle"
    class FieldRegistry
      # Default field type to partial mappings
      FIELD_TYPES = {
        # Basic types
        text: { partial: "admin/fields/text", input_type: :text_field },
        string: { partial: "admin/fields/text", input_type: :text_field },
        email: { partial: "admin/fields/text", input_type: :email_field },
        url: { partial: "admin/fields/text", input_type: :url_field },
        tel: { partial: "admin/fields/text", input_type: :telephone_field },
        password: { partial: "admin/fields/text", input_type: :password_field },
        number: { partial: "admin/fields/number", input_type: :number_field },
        integer: { partial: "admin/fields/number", input_type: :number_field },
        decimal: { partial: "admin/fields/number", input_type: :number_field },

        # Text areas
        textarea: { partial: "admin/fields/textarea", input_type: :text_area },
        text_area: { partial: "admin/fields/textarea", input_type: :text_area },

        # Boolean
        boolean: { partial: "admin/fields/toggle", input_type: :check_box },
        toggle: { partial: "admin/fields/toggle", input_type: nil },
        checkbox: { partial: "admin/fields/checkbox", input_type: :check_box },

        # Date/Time
        date: { partial: "admin/fields/date", input_type: :date_field },
        datetime: { partial: "admin/fields/datetime", input_type: :datetime_local_field },
        time: { partial: "admin/fields/time", input_type: :time_field },
        date_range: { partial: "admin/fields/date_range", input_type: nil },

        # Select
        select: { partial: "admin/fields/select", input_type: :select },
        searchable_select: { partial: "admin/fields/searchable_select", input_type: nil },
        collection_select: { partial: "admin/fields/collection_select", input_type: :collection_select },

        # Rich content
        rich_text: { partial: "admin/fields/rich_text", input_type: :rich_text_area },
        trix: { partial: "admin/fields/rich_text", input_type: :rich_text_area },
        markdown: { partial: "admin/fields/markdown", input_type: :text_area },

        # File
        file: { partial: "admin/fields/file", input_type: :file_field },
        image: { partial: "admin/fields/file", input_type: :file_field },

        # Special
        json: { partial: "admin/fields/json", input_type: :text_area },
        color: { partial: "admin/fields/color", input_type: :color_field },
        hidden: { partial: nil, input_type: :hidden_field },
        tag_picker: { partial: "admin/fields/tag_picker", input_type: nil },

        # Read-only display
        readonly: { partial: "admin/fields/readonly", input_type: nil },
        badge: { partial: "admin/fields/badge", input_type: nil }
      }.freeze

      class << self
        # Returns the partial path for a field type
        #
        # @param type [Symbol] Field type
        # @return [String, nil] Partial path or nil
        def partial_for(type)
          config = FIELD_TYPES[type.to_sym]
          config&.dig(:partial)
        end

        # Returns the input type for a field type
        #
        # @param type [Symbol] Field type
        # @return [Symbol, nil] Form builder input method
        def input_type_for(type)
          config = FIELD_TYPES[type.to_sym]
          config&.dig(:input_type)
        end

        # Checks if a field type uses a custom partial
        #
        # @param type [Symbol] Field type
        # @return [Boolean]
        def custom_partial?(type)
          partial_for(type).present?
        end

        # Returns all registered field types
        #
        # @return [Array<Symbol>]
        def types
          FIELD_TYPES.keys
        end

        # Checks if a field type is valid
        #
        # @param type [Symbol] Field type
        # @return [Boolean]
        def valid_type?(type)
          FIELD_TYPES.key?(type.to_sym)
        end

        # Returns options for rendering a field
        #
        # @param field_def [FieldDefinition] Field definition
        # @return [Hash] Options hash for rendering
        def options_for(field_def)
          {
            form: nil, # Set by caller
            field: field_def.name,
            label: field_def.label,
            help: field_def.help,
            placeholder: field_def.placeholder,
            required: field_def.required,
            readonly: field_def.readonly
          }.tap do |opts|
            # Add type-specific options
            case field_def.type
            when :select, :collection_select
              opts[:collection] = field_def.collection
            when :searchable_select
              opts[:search_url] = field_def.collection
              opts[:create_url] = field_def.create_url
              opts[:creatable] = field_def.create_url.present?
            when :file, :image
              opts[:accept] = field_def.accept
              opts[:preview] = field_def.type == :image
            when :textarea, :markdown
              opts[:rows] = field_def.rows || 6
            end
          end
        end
      end
    end
  end
end
