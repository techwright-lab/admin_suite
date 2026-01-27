# frozen_string_literal: true

module Admin
  module Resources
    # Resource definition for Assistant Thread admin management
    #
    # Provides read-only operations with search, filtering, and export functionality.
    class AssistantThreadResource < Admin::Base::Resource
      model ::Assistant::ChatThread
      portal :assistant
      section :threads

      index do
        searchable :title
        sortable default: :last_activity_at, direction: :desc
        paginate 20

        stats do
          stat :total, -> { ::Assistant::ChatThread.count }
          stat :open, -> { ::Assistant::ChatThread.where(status: "open").count }, color: :green
          stat :closed, -> { ::Assistant::ChatThread.where(status: "closed").count }, color: :slate
          stat :created_last_24h, -> { ::Assistant::ChatThread.where("created_at >= ?", 24.hours.ago).count }, color: :amber
        end

        columns do
          column :id
          column :title
          column :user, ->(t) { t.user&.email_address }
          column :status, sortable: true, type: :label, label_color: ->(t) {
            case t.status.to_sym
            when :open then :green
            when :closed then :slate
            else :gray
            end
          }
          column :last_activity_at, ->(t) { t.last_activity_at&.strftime("%b %d, %H:%M") }, sortable: true
          column :created_at, ->(t) { t.created_at&.strftime("%b %d, %H:%M") }, sortable: true
        end

        filters do
          filter :status, type: :select, options: [
            [ "All Statuses", "" ],
            [ "Open", "open" ],
            [ "Closed", "closed" ]
          ]
          filter :user_id, type: :number, label: "User ID"
        end
      end

      show do
        sidebar do
          panel :details, title: "Details", fields: [ :title, :status ]
          panel :user, title: "User", fields: [ :user ]
          panel :timestamps, title: "Activity", fields: [ :last_activity_at, :created_at, :updated_at ]
        end

        main do
          panel :messages, title: "Messages", render: :messages_preview
          panel :tool_executions, title: "Tool Executions",
                association: :tool_executions,
                limit: 20,
                display: :table,
                columns: [ :tool_key, :status, :duration_seconds, :created_at ],
                link_to: :internal_developer_assistant_tool_execution_path
          panel :turns, title: "Conversation Turns",
                association: :turns,
                limit: 20,
                display: :list,
                link_to: :internal_developer_assistant_turn_path
        end
      end

      actions do
        action :export, type: :link
      end

      exportable :json
    end
  end
end
