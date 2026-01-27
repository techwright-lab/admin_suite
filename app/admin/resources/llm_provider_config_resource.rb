# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for LLM Provider Config admin management
    #
    # Provides full CRUD for LLM provider configurations with test action.
    class LlmProviderConfigResource < Admin::Base::Resource
      model LlmProviderConfig
      portal :ai
      section :llm

      index do
        searchable :name, :llm_model
        sortable :name, :priority, :provider_type, default: :priority
        paginate 20

        stats do
          stat :total, -> { LlmProviderConfig.count }
          stat :enabled, -> { LlmProviderConfig.where(enabled: true).count }, color: :green
          stat :disabled, -> { LlmProviderConfig.where(enabled: false).count }, color: :slate
        end

        columns do
          column :name
          column :provider_type, header: "Provider"
          column :llm_model, header: "Model"
          column :priority
          column :enabled, type: :toggle, toggle_field: :enabled
          column :ready, ->(pc) { pc.ready? ? "Ready" : "Not Ready" }
        end

        filters do
          filter :enabled, type: :select, options: [
            [ "All", "" ],
            [ "Enabled", "true" ],
            [ "Disabled", "false" ]
          ]
          filter :provider_type, type: :select, label: "Provider", options: [
            [ "All Providers", "" ],
            [ "OpenAI", "openai" ],
            [ "Anthropic", "anthropic" ],
            [ "Google", "google" ]
          ]
          filter :sort, type: :select, options: [
            [ "Priority", "priority" ],
            [ "Name (A-Z)", "name" ],
            [ "Provider", "provider_type" ]
          ]
        end
      end

      form do
        section "Provider Details" do
          field :name, required: true

          row cols: 2 do
            field :provider_type, type: :select, required: true, collection: [
              [ "OpenAI", "openai" ],
              [ "Anthropic", "anthropic" ],
              [ "Google", "google" ]
            ]
            field :llm_model, required: true, label: "Model", placeholder: "e.g., gpt-4, claude-3-opus"
          end

          field :api_endpoint, type: :url, label: "API Endpoint", help: "Optional custom API endpoint"
        end

        section "Configuration" do
          row cols: 3 do
            field :priority, type: :number, help: "Lower = higher priority"
            field :max_tokens, type: :number
            field :temperature, type: :number
          end

          field :enabled, type: :toggle
        end

        section "Advanced Settings" do
          field :settings, type: :json, help: "Additional provider-specific settings as JSON"
        end
      end

      show do
        sidebar do
          panel :config, title: "Configuration", fields: [ :provider_type, :llm_model, :priority, :enabled ]
          panel :params, title: "Parameters", fields: [ :max_tokens, :temperature ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :details, title: "Provider Details", fields: [ :name, :api_endpoint ]
          panel :settings, title: "Advanced Settings", fields: [ :settings ]
        end
      end

      actions do
        action :test_provider, method: :post, label: "Test Provider",
               if: ->(pc) { pc.enabled? }
        action :enable, method: :post, unless: ->(pc) { pc.enabled? }
        action :disable, method: :post, if: ->(pc) { pc.enabled? }
      end

      exportable :json
    end
  end
end
