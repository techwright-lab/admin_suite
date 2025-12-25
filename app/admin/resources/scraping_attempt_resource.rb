# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Scraping Attempt admin management
    #
    # Provides observability into the scraping pipeline with event timeline.
    class ScrapingAttemptResource < Admin::Base::Resource
      model ScrapingAttempt
      portal :ops
      section :scraping

      index do
        sortable :created_at, :duration_seconds, default: :created_at
        paginate 30

        stats do
          stat :total_7d, -> { ScrapingAttempt.recent_period(7).count }
          stat :completed, -> { ScrapingAttempt.recent_period(7).where(status: :completed).count }, color: :green
          stat :failed, -> { ScrapingAttempt.recent_period(7).where(status: :failed).count }, color: :red
          stat :pending, -> { ScrapingAttempt.where(status: %w[pending fetching extracting]).count }, color: :amber
        end

        columns do
          column :job_listing, ->(sa) { sa.job_listing&.title&.truncate(40) }
          column :status
          column :domain
          column :extraction_method
          column :duration, ->(sa) { sa.duration_seconds ? "#{sa.duration_seconds}s" : "—" }
          column :created_at, ->(sa) { sa.created_at.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Pending", "pending" ],
            [ "Fetching", "fetching" ],
            [ "Extracting", "extracting" ],
            [ "Completed", "completed" ],
            [ "Failed", "failed" ]
          ]
          filter :extraction_method, type: :select, label: "Method", options: [
            [ "All Methods", "" ],
            [ "LLM", "llm" ],
            [ "Structured", "structured" ],
            [ "Fallback", "fallback" ]
          ]
          filter :date_from, type: :date, label: "From Date"
          filter :date_to, type: :date, label: "To Date"
        end
      end

      show do
        sidebar do
          panel :status, title: "Status", fields: [ :status, :extraction_method, :provider ]
          panel :timing, title: "Timing", fields: [ :duration_seconds, :created_at, :updated_at ]
          panel :error, title: "Error", fields: [ :failed_step, :error_message ]
          panel :job, title: "Job Listing",
                association: :job_listing,
                link_to: :internal_developer_ops_job_listing_path
        end

        main do
          panel :events, title: "Scraping Events",
                association: :scraping_events,
                limit: 50,
                display: :table,
                columns: [ :step_order, :event_type_display, :status, :duration_ms, :created_at ],
                link_to: :internal_developer_ops_scraping_event_path
          panel :html_logs, title: "HTML Scraping Logs",
                association: :html_scraping_logs,
                limit: 10,
                display: :table,
                columns: [ :domain, :status, :extraction_rate, :duration_ms, :created_at ],
                link_to: :internal_developer_ops_html_scraping_log_path
          panel :logs, title: "LLM API Logs",
                association: :llm_api_logs,
                limit: 10,
                display: :table,
                columns: [ :provider, :model, :status, :latency_ms, :created_at ],
                link_to: :internal_developer_ai_llm_api_log_path
        end
      end

      actions do
        action :mark_failed, method: :post, label: "Mark Failed",
               confirm: "Mark this attempt as failed?",
               unless: ->(sa) { %w[completed failed].include?(sa.status) }
        action :retry_attempt, method: :post, label: "Retry",
               if: ->(sa) { sa.status == "failed" }
        collection_action :cleanup_stuck, method: :post, label: "Cleanup Stuck Attempts"
      end

      exportable :json
    end
  end
end
