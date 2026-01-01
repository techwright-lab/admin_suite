# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for LLM API Log admin management
    #
    # Provides read-only access to LLM API call logs for debugging.
    class LlmApiLogResource < Admin::Base::Resource
      model ::Ai::LlmApiLog
      portal :ai
      section :logs

      index do
        sortable :created_at, default: :created_at, direction: :desc
        paginate 30

        stats do
          stat :total_7d, -> { ::Ai::LlmApiLog.recent_period(7).count }
          stat :success, -> { ::Ai::LlmApiLog.recent_period(7).where(status: :success).count }, color: :green
          stat :failed, -> { ::Ai::LlmApiLog.recent_period(7).where(status: :failed).count }, color: :red
          stat :avg_latency, -> { "#{::Ai::LlmApiLog.recent_period(7).where.not(latency_ms: nil).average(:latency_ms).to_f.round(0)}ms" }, color: :blue
        end

        columns do
          column :operation_type, ->(log) { log.operation_type&.humanize }, header: "Operation"
          column :provider
          column :model
          column :status
          column :latency, ->(log) { log.latency_ms ? "#{log.latency_ms}ms" : "—" }
          column :tokens, ->(log) { "#{log.input_tokens || 0} / #{log.output_tokens || 0}" }, header: "In/Out Tokens"
          column :created_at, ->(log) { log.created_at.strftime("%b %d, %H:%M:%S") }, sortable: true
        end

        filters do
          filter :provider, type: :select, options: [
            [ "All Providers", "" ],
            [ "OpenAI", "openai" ],
            [ "Anthropic", "anthropic" ],
            [ "Google", "google" ]
          ]
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Success", "success" ],
            [ "Failed", "failed" ],
            [ "Pending", "pending" ]
          ]
          filter :operation_type, type: :select, label: "Operation", options: [
            [ "All Operations", "" ],
            [ "Job Extraction", "job_extraction" ],
            [ "Chat Completion", "chat_completion" ],
            [ "Memory Extraction", "memory_extraction" ]
          ]
          filter :date_from, type: :date, label: "From Date"
          filter :date_to, type: :date, label: "To Date"
        end
      end

      show do
        sidebar do
          panel :meta, title: "Request Info", fields: [ :operation_type, :provider, :model, :status ]
          panel :performance, title: "Performance", fields: [ :latency_ms, :input_tokens, :output_tokens, :estimated_cost_cents ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at ]
        end

        main do
          panel :loggable, title: "Source", fields: [ :loggable ]
          panel :prompt, title: "Prompt/Input", fields: [ :llm_prompt ]
          panel :request, title: "Request Payload", fields: [ :request_payload ]
          panel :response, title: "Response Payload", fields: [ :response_payload ]
          panel :error, title: "Error Details", fields: [ :error_type, :error_message ]
        end
      end

      exportable :json
    end
  end
end
