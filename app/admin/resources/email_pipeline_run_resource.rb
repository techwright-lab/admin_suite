# frozen_string_literal: true

module Admin
  module Resources
    class EmailPipelineRunResource < Admin::Base::Resource
      model Signals::EmailPipelineRun
      portal :email
      section :pipeline

      index do
        sortable :created_at, default: :created_at, direction: :desc
        paginate 30

        stats do
          stat :total, -> { Signals::EmailPipelineRun.count }
          stat :started, -> { Signals::EmailPipelineRun.where(status: :started).count }, color: :amber
          stat :success, -> { Signals::EmailPipelineRun.where(status: :success).count }, color: :green
          stat :failed, -> { Signals::EmailPipelineRun.where(status: :failed).count }, color: :red
        end

        columns do
          column :id
          column :status, type: :label, label_color: ->(r) {
            case r.status.to_sym
            when :started then :amber
            when :success then :green
            when :failed then :red
            else :gray
            end
          }
          column :trigger
          column :mode
          column :synced_email_id, header: "Email"
          column :duration_ms, header: "Duration"
          column :created_at, ->(r) { r.created_at.strftime("%b %d, %H:%M:%S") }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All", "" ],
            [ "Started", "started" ],
            [ "Success", "success" ],
            [ "Failed", "failed" ]
          ]
          filter :trigger, type: :text, placeholder: "gmail_sync / manual ..."
        end
      end

      show do
        sidebar do
          panel :meta, title: "Run", fields: [ :status, :trigger, :mode ]
          panel :timestamps, title: "Timestamps", fields: [ :started_at, :completed_at, :created_at ]
          panel :email, title: "Synced Email", association: :synced_email
        end

        main do
          panel :events, title: "Events", association: :events, display: :table, columns: [ :step_order, :event_type, :status, :duration_ms, :created_at ]
          panel :error, title: "Error", fields: [ :error_type, :error_message ]
          panel :metadata, title: "Metadata", fields: [ :metadata ]
        end
      end

      exportable :json
    end
  end
end
