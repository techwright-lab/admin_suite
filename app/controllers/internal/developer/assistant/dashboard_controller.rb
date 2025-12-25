# frozen_string_literal: true

module Internal
  module Developer
    module Assistant
      # Dashboard for the Assistant Portal
      class DashboardController < BaseController
        before_action :load_resources!

        # GET /internal/developer/assistant
        def index
          @resources_by_section = build_resources_by_section
          @stats = calculate_portal_stats
          @health = calculate_health_metrics
          @charts = build_chart_data
          @recent = build_recent_activity
        end

        private

        def build_resources_by_section
          resources = {}

          portal_resources.each do |resource|
            section = resource.section_name || :general
            resources[section] ||= []
            resources[section] << resource
          end

          resources
        end

        def calculate_portal_stats
          {
            total_resources: portal_resources.count,
            threads: ::Assistant::ChatThread.count,
            open_threads: ::Assistant::ChatThread.where(status: "open").count,
            tool_executions: ::Assistant::ToolExecution.count,
            pending_approvals: ::Assistant::ToolExecution.where(status: :pending_approval).count,
            tools: ::Assistant::Tool.count,
            active_tools: ::Assistant::Tool.where(enabled: true).count,
            user_memories: ::Assistant::Memory::UserMemory.count
          }
        end

        def calculate_health_metrics
          recent_threads = ::Assistant::ChatThread.where("created_at > ?", 24.hours.ago)
          recent_executions = ::Assistant::ToolExecution.where("created_at > ?", 24.hours.ago)

          total_executions = recent_executions.count
          successful = recent_executions.where(status: :completed).count
          failed = recent_executions.where(status: :failed).count
          pending = ::Assistant::ToolExecution.where(status: :pending_approval).count

          success_rate = total_executions > 0 ? (successful.to_f / total_executions * 100).round : 100
          status = if pending > 20 || (total_executions > 10 && success_rate < 70)
                     :degraded
                   elsif failed > 10
                     :critical
                   else
                     :healthy
                   end

          {
            status: status,
            threads_24h: recent_threads.count,
            executions_24h: total_executions,
            successful: successful,
            failed: failed,
            pending: pending,
            success_rate: success_rate
          }
        end

        def build_chart_data
          # Last 7 days of threads
          threads_by_day = (0..6).map do |i|
            date = i.days.ago.to_date
            count = ::Assistant::ChatThread.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse

          # Last 7 days of tool executions
          executions_by_day = (0..6).map do |i|
            date = i.days.ago.to_date
            count = ::Assistant::ToolExecution.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse

          { threads: threads_by_day, executions: executions_by_day }
        end

        def build_recent_activity
          {
            threads: ::Assistant::ChatThread.includes(:user).order(created_at: :desc).limit(5),
            executions: ::Assistant::ToolExecution.order(created_at: :desc).limit(5),
            pending_approvals: ::Assistant::ToolExecution.where(status: :pending_approval).order(created_at: :desc).limit(5)
          }
        end
      end
    end
  end
end

