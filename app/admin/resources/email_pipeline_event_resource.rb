# frozen_string_literal: true

module Admin
  module Resources
    class EmailPipelineEventResource < Admin::Base::Resource
      model Signals::EmailPipelineEvent
      portal :email
      section :pipeline

      index do
        sortable :created_at, default: :created_at, direction: :desc
        paginate 50

        stats do
          stat :total, -> { Signals::EmailPipelineEvent.count }
          stat :success, -> { Signals::EmailPipelineEvent.where(status: :success).count }, color: :green
          stat :failed, -> { Signals::EmailPipelineEvent.where(status: :failed).count }, color: :red
          stat :started, -> { Signals::EmailPipelineEvent.where(status: :started).count }, color: :amber
        end

        columns do
          column :event_type, header: "Event"
          column :status, type: :label, label_color: ->(e) {
            case e.status.to_sym
            when :started then :amber
            when :success then :green
            when :failed then :red
            when :skipped then :purple
            else :gray
            end
          }
          column :duration_ms, header: "Duration"
          column :step_order, header: "Step"
          column :run_id, header: "Run"
          column :synced_email_id, header: "Email"
          column :created_at, ->(e) { e.created_at.strftime("%b %d, %H:%M:%S") }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All", "" ],
            [ "Started", "started" ],
            [ "Success", "success" ],
            [ "Failed", "failed" ],
            [ "Skipped", "skipped" ]
          ]
          filter :event_type, type: :text, placeholder: "event_type..."
        end
      end

      show do
        sidebar do
          panel :meta, title: "Event", fields: [ :event_type, :status, :duration_ms, :step_order ]
          panel :timestamps, title: "Timestamps", fields: [ :started_at, :completed_at, :created_at ]
          panel :run, title: "Run", association: :run
          panel :email, title: "Email", association: :synced_email
        end

        main do
          panel :error, title: "Error", fields: [ :error_type, :error_message ]
          panel :input, title: "Input Payload", fields: [ :input_payload ]
          panel :output, title: "Output Payload", fields: [ :output_payload ]
          panel :metadata, title: "Metadata", fields: [ :metadata ]
        end
      end

      exportable :json
    end
  end
end
