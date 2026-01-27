# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Assistant Event admin management
    #
    # Provides read-only access to assistant events for debugging.
    class AssistantEventResource < Admin::Base::Resource
      model ::Assistant::Ops::Event
      portal :assistant
      section :events

      index do
        sortable :created_at, default: :created_at
        paginate 50

        stats do
          stat :total, -> { ::Assistant::Ops::Event.count }
          stat :info, -> { ::Assistant::Ops::Event.where(severity: "info").count }, color: :blue
          stat :warn, -> { ::Assistant::Ops::Event.where(severity: "warn").count }, color: :amber
          stat :error, -> { ::Assistant::Ops::Event.where(severity: "error").count }, color: :red
          stat :last_24h, -> { ::Assistant::Ops::Event.where("created_at >= ?", 24.hours.ago).count }
        end

        columns do
          column :event_type, header: "Event"
          column :severity, type: :label, label_color: ->(e) {
            case e.severity.to_sym
            when :info then :blue
            when :warn then :amber
            when :error then :red
            else :gray
            end
          }
          column :thread, ->(e) { e.thread&.display_title&.truncate(25) }
          column :trace_id, ->(e) { e.trace_id&.truncate(12) }
          column :created_at, ->(e) { e.created_at.strftime("%b %d, %H:%M:%S") }
        end

        filters do
          filter :event_type, type: :text, placeholder: "Event type..."
          filter :severity, type: :select, options: [
            [ "All", "" ],
            [ "Info", "info" ],
            [ "Warning", "warn" ],
            [ "Error", "error" ]
          ]
          filter :trace_id, type: :text, placeholder: "Trace ID..."
          filter :thread_id, type: :number, label: "Thread ID"
        end
      end

      show do
        sidebar do
          panel :event, title: "Event", fields: [ :event_type, :severity ]
          panel :ids, title: "Identifiers", fields: [ :trace_id ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at ]
        end

        main do
          panel :thread, title: "Thread", fields: [ :thread ]
          panel :payload, title: "Payload", fields: [ :payload ]
        end
      end

      exportable :json
    end
  end
end
