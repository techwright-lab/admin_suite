# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Assistant Thread Summary admin management
    #
    # Provides read-only access to thread summaries for debugging.
    class AssistantThreadSummaryResource < Admin::Base::Resource
      model ::Assistant::Memory::ThreadSummary
      portal :assistant
      section :memory

      index do
        sortable :created_at, :summary_version, default: :created_at
        paginate 30

        stats do
          stat :total, -> { ::Assistant::Memory::ThreadSummary.count }
          stat :with_llm_log, -> { ::Assistant::Memory::ThreadSummary.where.not(llm_api_log_id: nil).count }, color: :blue
          stat :recent_24h, -> { ::Assistant::Memory::ThreadSummary.where("created_at >= ?", 24.hours.ago).count }, color: :green
        end

        columns do
          column :thread, ->(ts) { ts.thread&.display_title&.truncate(40) }
          column :user, ->(ts) { ts.thread&.user&.email_address }
          column :summary_version, header: "Version"
          column :created_at, ->(ts) { ts.created_at.strftime("%b %d, %H:%M") }
        end

        filters do
          filter :thread_id, type: :number, label: "Thread ID"
          filter :user_id, type: :number, label: "User ID"
          filter :version, type: :number, label: "Version"
        end
      end

      show do
        sidebar do
          panel :meta, title: "Metadata", fields: [ :summary_version, :last_summarized_message ]
          panel :timestamps, title: "Timestamps", fields: [ :created_at, :updated_at ]
        end

        main do
          panel :thread, title: "Thread", fields: [ :thread ]
          panel :content, title: "Summary Content", fields: [ :summary_text ]
          panel :llm, title: "LLM API Log", association: :llm_api_log
        end
      end

      exportable :json
    end
  end
end
