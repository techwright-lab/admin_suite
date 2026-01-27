# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Assistant Turn admin management
    #
    # Provides read-only access to conversation turns for debugging.
    class AssistantTurnResource < Admin::Base::Resource
      model ::Assistant::Turn
      portal :assistant
      section :turns

      index do
        sortable :created_at, default: :created_at
        paginate 30

        stats do
          stat :total, -> { ::Assistant::Turn.count }
          stat :success, -> { ::Assistant::Turn.where(status: "success").count }, color: :green
          stat :error, -> { ::Assistant::Turn.where(status: "error").count }, color: :red
          stat :last_24h, -> { ::Assistant::Turn.where("created_at >= ?", 24.hours.ago).count }, color: :blue
        end

        columns do
          column :thread, ->(t) { t.thread&.display_title&.truncate(30) }
          column :status, type: :label, label_color: ->(t) {
            case t.status.to_sym
            when :success then :green
            when :error then :red
            when :pending then :amber
            else :gray
            end
          }
          column :trace_id, ->(t) { t.trace_id&.truncate(12) }
          column :latency_ms, ->(t) { t.latency_ms ? "#{t.latency_ms}ms" : "—" }, header: "Latency"
          column :created_at, ->(t) { t.created_at.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Success", "success" ],
            [ "Error", "error" ],
            [ "Pending", "pending" ]
          ]
          filter :trace_id, type: :text, placeholder: "Trace ID..."
          filter :thread_id, type: :number, label: "Thread ID"
        end
      end

      show do
        sidebar do
          panel :status, title: "Status", fields: [ :status, :latency_ms ]
          panel :ids, title: "Identifiers", fields: [ :trace_id, :uuid ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :thread, title: "Thread", fields: [ :thread ]
          panel :messages, title: "Messages", render: :turn_messages_preview
          panel :context, title: "Context Snapshot", fields: [ :context_snapshot ]
          panel :llm_log, title: "LLM API Log", association: :llm_api_log
        end
      end

      exportable :json
    end
  end
end
