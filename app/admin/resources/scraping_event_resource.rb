# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Scraping Event admin management
    #
    # Provides read-only access to scraping events for debugging.
    class ScrapingEventResource < Admin::Base::Resource
      model ScrapingEvent
      portal :ops
      section :scraping

      index do
        sortable :created_at, default: :created_at
        paginate 50

        stats do
          stat :total, -> { ScrapingEvent.count }
          stat :success, -> { ScrapingEvent.where(status: :success).count }, color: :green
          stat :failed, -> { ScrapingEvent.where(status: :failed).count }, color: :red
          stat :skipped, -> { ScrapingEvent.where(status: :skipped).count }, color: :slate
        end

        columns do
          column :step_name, ->(e) { e.event_type_display }, header: "Step"
          column :status
          column :duration, ->(e) { e.duration_ms ? "#{e.duration_ms}ms" : "—" }
          column :scraping_attempt, ->(e) { "##{e.scraping_attempt_id}" }, header: "Attempt"
          column :created_at, ->(e) { e.created_at.strftime("%b %d, %H:%M:%S") }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Started", "started" ],
            [ "Success", "success" ],
            [ "Failed", "failed" ],
            [ "Skipped", "skipped" ]
          ]
          filter :step_name, type: :text, placeholder: "Step name..."
        end
      end

      show do
        sidebar do
          panel :event, title: "Event Info", fields: [ :step_name, :status, :duration_ms ]
          panel :timestamps, title: "Timestamps", fields: [ :started_at, :completed_at, :created_at ]
          panel :attempt, title: "Scraping Attempt",
                association: :scraping_attempt,
                link_to: :internal_developer_ops_scraping_attempt_path
        end

        main do
          panel :error, title: "Error Details", fields: [ :error_type, :error_message ]
          panel :input, title: "Input Payload", fields: [ :input_payload ]
          panel :output, title: "Output Payload", fields: [ :output_payload ]
          panel :metadata, title: "Metadata", fields: [ :metadata ]
        end
      end

      exportable :json
    end
  end
end
