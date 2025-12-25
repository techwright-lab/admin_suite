# frozen_string_literal: true

module Internal
  module Developer
    module Ai
      # Dashboard for the AI Portal
      class DashboardController < BaseController
        before_action :load_resources!

        # GET /internal/developer/ai
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
            llm_prompts: ::Ai::LlmPrompt.count,
            active_prompts: ::Ai::LlmPrompt.where(active: true).count,
            provider_configs: ::LlmProviderConfig.count,
            enabled_providers: ::LlmProviderConfig.where(enabled: true).count,
            api_logs: ::Ai::LlmApiLog.count
          }
        end

        def calculate_health_metrics
          recent_logs = ::Ai::LlmApiLog.where("created_at > ?", 24.hours.ago)
          total = recent_logs.count
          successful = recent_logs.where(status: :success).count
          failed = recent_logs.where(status: :failed).count

          avg_latency = recent_logs.where(status: :success).average(:latency_ms)&.round || 0
          total_cost_cents = recent_logs.sum(:estimated_cost_cents) || 0
          total_cost = (total_cost_cents / 100.0).round(2)
          total_tokens = recent_logs.sum(:total_tokens) || 0

          success_rate = total > 0 ? (successful.to_f / total * 100).round : 100
          status = if total > 10 && success_rate < 80
                     :critical
                   elsif total > 10 && success_rate < 95
                     :degraded
                   else
                     :healthy
                   end

          {
            status: status,
            total: total,
            successful: successful,
            failed: failed,
            success_rate: success_rate,
            avg_latency: avg_latency,
            total_cost: total_cost,
            total_tokens: total_tokens
          }
        end

        def build_chart_data
          # Last 7 days of API calls
          api_calls_by_day = (0..6).map do |i|
            date = i.days.ago.to_date
            count = ::Ai::LlmApiLog.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse

          # Cost by day (in cents)
          cost_by_day = (0..6).map do |i|
            date = i.days.ago.to_date
            cost_cents = ::Ai::LlmApiLog.where(created_at: date.beginning_of_day..date.end_of_day).sum(:estimated_cost_cents) || 0
            { label: date.strftime("%a"), value: cost_cents }
          end.reverse

          { api_calls: api_calls_by_day, cost: cost_by_day }
        end

        def build_recent_activity
          {
            api_logs: ::Ai::LlmApiLog.order(created_at: :desc).limit(5),
            prompts: ::Ai::LlmPrompt.order(updated_at: :desc).limit(5)
          }
        end
      end
    end
  end
end

