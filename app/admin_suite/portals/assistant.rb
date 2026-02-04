# frozen_string_literal: true

AdminSuite.portal :assistant do
  label "Assistant Portal"
  icon "message-circle"
  color :violet
  order 40
  description "Chat, Tools & Memory management"

  dashboard do
    row do
      health_panel "Assistant System",
        span: 4,
        status: lambda {
          recent_executions = ::Assistant::ToolExecution.where("created_at > ?", 24.hours.ago)
          total = recent_executions.count
          successful = recent_executions.where(status: :completed).count
          pending = ::Assistant::ToolExecution.where(status: :pending_approval).count
          failed = recent_executions.where(status: :failed).count
          success_rate = total > 0 ? (successful.to_f / total * 100).round : 100

          if failed > 10
            :critical
          elsif pending > 20 || (total > 10 && success_rate < 70)
            :degraded
          else
            :healthy
          end
        },
        metrics: lambda {
          recent_threads = ::Assistant::ChatThread.where("created_at > ?", 24.hours.ago)
          recent_executions = ::Assistant::ToolExecution.where("created_at > ?", 24.hours.ago)

          total = recent_executions.count
          successful = recent_executions.where(status: :completed).count
          pending = ::Assistant::ToolExecution.where(status: :pending_approval).count
          failed = recent_executions.where(status: :failed).count
          success_rate = total > 0 ? (successful.to_f / total * 100).round : 100

          {
            "24h threads" => recent_threads.count,
            "24h tool runs" => total,
            "success rate" => "#{success_rate}%",
            "pending approval" => pending,
            "failed" => failed
          }
        }

      chart_panel "Threads (7 days)",
        span: 4,
        data: lambda {
          (0..6).map do |i|
            date = i.days.ago.to_date
            count = ::Assistant::ChatThread.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse
        }

      chart_panel "Tool Runs (7 days)",
        span: 4,
        data: lambda {
          (0..6).map do |i|
            date = i.days.ago.to_date
            count = ::Assistant::ToolExecution.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse
        }
    end

    row do
      stat_panel "Threads", -> { ::Assistant::ChatThread.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Open", -> { ::Assistant::ChatThread.where(status: "open").count }, span: 2, variant: :mini, color: :green
      stat_panel "Tool Runs", -> { ::Assistant::ToolExecution.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Active Tools", -> { ::Assistant::Tool.where(enabled: true).count }, span: 2, variant: :mini, color: :green
      stat_panel "Memories", -> { ::Assistant::Memory::UserMemory.count }, span: 2, variant: :mini, color: :cyan
      stat_panel "Resources", -> { Admin::Base::Resource.resources_for_portal(:assistant).count }, span: 2, variant: :mini, color: :violet
    end

    row do
      recent_panel "Recent Threads",
        span: 6,
        scope: -> { ::Assistant::ChatThread.includes(:user).order(created_at: :desc).limit(8) },
        view_all_path: ->(view) { view.resources_path(portal: :assistant, resource_name: "assistant_threads") }

      recent_panel "Recent Tool Runs",
        span: 4,
        scope: -> { ::Assistant::ToolExecution.order(created_at: :desc).limit(8) },
        view_all_path: ->(view) { view.resources_path(portal: :assistant, resource_name: "assistant_tool_executions") }

      stat_panel "Pending Approvals",
        -> { ::Assistant::ToolExecution.where(status: :pending_approval).count },
        span: 2,
        variant: :mini,
        color: :amber
    end

    row do
      cards_panel "Assistant Management",
        span: 12,
        resources: begin
          items = [
          { resource_name: "assistant_tools", label: "Tools", description: "Manage tool definitions", icon: "wrench", count: -> { ::Assistant::Tool.count } },
          { resource_name: "assistant_threads", label: "Threads", description: "Monitor ongoing conversations", icon: "message-square", count: -> { ::Assistant::ChatThread.count } },
          { resource_name: "assistant_turns", label: "Turns", description: "Conversation turns", icon: "repeat", count: -> { ::Assistant::Turn.count } }
          ]

          # `Assistant::Event` is optional; some deployments don't ship it.
          if defined?(::Assistant::Event)
            items << { resource_name: "assistant_events", label: "Events", description: "System events", icon: "clock", count: -> { ::Assistant::Event.count } }
          end

          items
        end
    end
  end
end
