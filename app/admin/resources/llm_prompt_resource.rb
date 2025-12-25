# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for LLM Prompt admin management
    #
    # Provides CRUD operations with activate and duplicate actions.
    class LlmPromptResource < Admin::Base::Resource
      model ::Ai::LlmPrompt
      portal :ai
      section :llm

      index do
        searchable :name, :description
        sortable :name, :type, :version, :created_at, default: :type
        paginate 20

        stats do
          stat :total, -> { ::Ai::LlmPrompt.count }
          stat :active, -> { ::Ai::LlmPrompt.where(active: true).count }, color: :green
          stat :inactive, -> { ::Ai::LlmPrompt.where(active: false).count }, color: :slate
        end

        columns do
          column :name
          column :type, ->(p) { p.type.demodulize.titleize }
          column :version
          column :active, ->(p) { p.active? ? "Active" : "Inactive" }
        end

        filters do
          filter :prompt_type, type: :select, label: "Type", options: [
            [ "All Types", "" ],
            [ "Job Extraction", "job_extraction" ],
            [ "Email Extraction", "email_extraction" ],
            [ "Resume Extraction", "resume_extraction" ],
            [ "Assistant System", "assistant_system" ],
            [ "Thread Summary", "assistant_thread_summary" ],
            [ "Memory Proposal", "assistant_memory_proposal" ]
          ]
          filter :active, type: :select, options: [
            [ "All", "" ],
            [ "Active Only", "true" ],
            [ "Inactive Only", "false" ]
          ]
          filter :sort, type: :select, options: [
            [ "By Type", "type" ],
            [ "By Name", "name" ],
            [ "By Version", "version" ],
            [ "Recently Added", "recent" ]
          ]
        end
      end

      form do
        section "Basic Information" do
          field :name, required: true
          field :description, type: :textarea, rows: 3

          row cols: 2 do
            field :version, type: :number, min: 1
            field :active, type: :toggle
          end
        end

        section "Prompt Template" do
          field :prompt_template, type: :markdown, rows: 20,
                help: "Use {{variable_name}} for template variables"
        end
      end

      show do
        sidebar do
          panel :metadata, title: "Metadata", fields: [ :type, :version, :active ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end
        
        main do
          panel :info, title: "Information", fields: [ :name, :description ]
          panel :template, title: "Prompt Template", render: :prompt_template_preview
          panel :api_logs, title: "Recent API Logs",
                association: :llm_api_logs,
                limit: 10,
                display: :table,
                columns: [:provider, :model, :status, :latency_ms, :created_at],
                link_to: :internal_developer_ai_llm_api_log_path
        end
      end

      actions do
        action :activate, method: :post, label: "Activate",
               confirm: "This will deactivate all other prompts of the same type.",
               unless: ->(p) { p.active? }
        action :duplicate, method: :post, label: "Duplicate"
      end

      exportable :json
    end
  end
end

