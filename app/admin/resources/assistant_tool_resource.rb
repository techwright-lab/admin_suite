# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Assistant Tool admin management
    #
    # Provides full CRUD for assistant tools with schema editing.
    class AssistantToolResource < Admin::Base::Resource
      model ::Assistant::Tool
      portal :assistant
      section :tools

      index do
        searchable :tool_key, :name, :description
        sortable default: :tool_key, direction: :asc
        paginate 30

        stats do
          stat :total, -> { ::Assistant::Tool.count }
          stat :enabled, -> { ::Assistant::Tool.where(enabled: true).count }, color: :green
          stat :read_only, -> { ::Assistant::Tool.where(risk_level: "read_only").count }, color: :blue
          stat :write, -> { ::Assistant::Tool.where("risk_level LIKE 'write%'").count }, color: :amber
        end

        columns do
          column :tool_key, header: "Key", sortable: true
          column :name, sortable: true
          column :risk_level, header: "Risk", sortable: true
          column :enabled, type: :toggle, toggle_field: :enabled
          column :requires_confirmation, ->(t) { t.requires_confirmation? ? "Yes" : "No" }, header: "Confirm"
          column :timeout_ms, ->(t) { "#{t.timeout_ms}ms" }, header: "Timeout"
        end

        filters do
          filter :enabled, type: :select, options: [
            [ "All", "" ],
            [ "Enabled", "true" ],
            [ "Disabled", "false" ]
          ]
          filter :risk_level, type: :select, label: "Risk", options: [
            [ "All Levels", "" ],
            [ "Read Only", "read_only" ],
            [ "Write Low", "write_low" ],
            [ "Write High", "write_high" ]
          ]
          filter :requires_confirmation, type: :select, label: "Confirmation", options: [
            [ "All", "" ],
            [ "Required", "true" ],
            [ "Not Required", "false" ]
          ]
        end
      end

      form do
        section "Tool Definition" do
          field :tool_key, required: true, help: "Unique identifier (snake_case)"
          field :name, required: true
          field :description, type: :textarea, rows: 3, required: true
          field :executor_class, required: true, help: "Fully qualified class name"
        end

        section "Configuration" do
          row cols: 2 do
            field :risk_level, type: :select, required: true, collection: [
              [ "Read Only", "read_only" ],
              [ "Write Low", "write_low" ],
              [ "Write High", "write_high" ]
            ]
            field :timeout_ms, type: :number, label: "Timeout (ms)"
          end

          row cols: 2 do
            field :enabled, type: :toggle
            field :requires_confirmation, type: :toggle
          end
        end

        section "Schema" do
          field :arg_schema, type: :json, label: "Argument Schema",
                help: "JSON Schema for tool arguments"
          field :rate_limit, type: :json, help: "Rate limiting configuration"
        end
      end

      show do
        sidebar do
          panel :config, title: "Configuration", fields: [ :risk_level, :enabled, :requires_confirmation ]
          panel :execution, title: "Execution", fields: [ :executor_class, :timeout_ms ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :tool, title: "Tool Definition", fields: [ :tool_key, :name, :description ]
          panel :schema, title: "Argument Schema", fields: [ :arg_schema ]
          panel :limits, title: "Rate Limits", fields: [ :rate_limit ]
        end
      end

      actions do
        action :enable, method: :post, unless: ->(t) { t.enabled? }
        action :disable, method: :post, if: ->(t) { t.enabled? }
      end

      exportable :json
    end
  end
end
