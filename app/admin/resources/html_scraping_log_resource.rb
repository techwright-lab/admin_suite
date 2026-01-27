# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for HTML Scraping Log admin management
    #
    # Provides read-only access to HTML scraping logs for debugging.
    class HtmlScrapingLogResource < Admin::Base::Resource
      model HtmlScrapingLog
      portal :ops
      section :scraping

      index do
        sortable :created_at, default: :created_at
        paginate 30

        stats do
          stat :total_7d, -> { HtmlScrapingLog.recent_period(7).count }
          stat :success, -> { HtmlScrapingLog.recent_period(7).where(status: :success).count }, color: :green
          stat :partial, -> { HtmlScrapingLog.recent_period(7).where(status: :partial).count }, color: :amber
          stat :failed, -> { HtmlScrapingLog.recent_period(7).where(status: :failed).count }, color: :red
        end

        columns do
          column :domain
          column :status, type: :label, label_color: ->(log) {
            case log.status.to_sym
            when :success then :green
            when :partial then :amber
            when :failed then :red
            else :gray
            end
          }
          column :extraction_rate, ->(log) { "#{(log.extraction_rate.to_f * 100).round(1)}%" }, header: "Rate"
          column :duration, ->(log) { log.duration_ms ? "#{log.duration_ms}ms" : "—" }
          column :fetch_mode, header: "Mode"
          column :board_type, header: "Board"
          column :created_at, ->(log) { log.created_at.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Success", "success" ],
            [ "Partial", "partial" ],
            [ "Failed", "failed" ]
          ]
          filter :fetch_mode, type: :select, label: "Mode", options: [
            [ "All Modes", "" ],
            [ "Direct", "direct" ],
            [ "Browser", "browser" ]
          ]
          filter :board_type, type: :select, label: "Board", options: [
            [ "All Boards", "" ],
            [ "Greenhouse", "greenhouse" ],
            [ "Lever", "lever" ],
            [ "Workday", "workday" ],
            [ "Custom", "custom" ]
          ]
          filter :date_from, type: :date, label: "From Date"
          filter :date_to, type: :date, label: "To Date"
        end
      end

      show do
        sidebar do
          panel :meta, title: "Log Info", fields: [ :domain, :status, :fetch_mode, :board_type ]
          panel :performance, title: "Performance", fields: [ :duration_ms, :extraction_rate ]
          panel :context, title: "Context", fields: [ :extractor_kind, :run_context ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at ]
          panel :attempt, title: "Scraping Attempt",
                association: :scraping_attempt,
                link_to: :internal_developer_ops_scraping_attempt_path
          panel :job, title: "Job Listing",
                association: :job_listing,
                link_to: :internal_developer_ops_job_listing_path
        end

        main do
          panel :fields, title: "Field Results", fields: [ :field_results ]
          panel :html, title: "HTML Content", fields: [ :raw_html ]
        end
      end

      exportable :json
    end
  end
end
