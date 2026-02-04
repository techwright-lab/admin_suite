# frozen_string_literal: true

AdminSuite.portal :ai do
  label "AI Portal"
  icon "cpu"
  color :cyan
  order 30
  description "LLM & Machine Learning management"

  dashboard do
    row do
      health_panel "LLM API",
        span: 4,
        status: lambda {
          recent_logs = ::Ai::LlmApiLog.where("created_at > ?", 24.hours.ago)
          total = recent_logs.count
          successful = recent_logs.where(status: :success).count
          success_rate = total > 0 ? (successful.to_f / total * 100).round : 100

          if total > 10 && success_rate < 80
            :critical
          elsif total > 10 && success_rate < 95
            :degraded
          else
            :healthy
          end
        },
        metrics: lambda {
          recent_logs = ::Ai::LlmApiLog.where("created_at > ?", 24.hours.ago)
          total = recent_logs.count
          successful = recent_logs.where(status: :success).count
          failed = recent_logs.where(status: :failed).count
          avg_latency = recent_logs.where(status: :success).average(:latency_ms)&.round || 0
          total_cost_cents = recent_logs.sum(:estimated_cost_cents) || 0
          total_cost = (total_cost_cents / 100.0).round(2)
          success_rate = total > 0 ? (successful.to_f / total * 100).round : 100

          {
            "24h calls" => total,
            "success rate" => "#{success_rate}%",
            "avg latency" => "#{avg_latency}ms",
            "24h cost" => "$#{total_cost}",
            "failed" => failed
          }
        }

      chart_panel "API Calls (7 days)",
        span: 4,
        data: lambda {
          (0..6).map do |i|
            date = i.days.ago.to_date
            count = ::Ai::LlmApiLog.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse
        }

      chart_panel "Cost (7 days, cents)",
        span: 4,
        data: lambda {
          (0..6).map do |i|
            date = i.days.ago.to_date
            cost_cents = ::Ai::LlmApiLog.where(created_at: date.beginning_of_day..date.end_of_day).sum(:estimated_cost_cents) || 0
            { label: date.strftime("%a"), value: cost_cents }
          end.reverse
        }
    end

    row do
      stat_panel "LLM Prompts", -> { ::Ai::LlmPrompt.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Active Prompts", -> { ::Ai::LlmPrompt.where(active: true).count }, span: 2, variant: :mini, color: :green
      stat_panel "Provider Configs", -> { ::LlmProviderConfig.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Enabled Providers", -> { ::LlmProviderConfig.where(enabled: true).count }, span: 2, variant: :mini, color: :cyan
      stat_panel "API Logs", -> { ::Ai::LlmApiLog.count }, span: 2, variant: :mini, color: :slate
      stat_panel "Resources", -> { Admin::Base::Resource.resources_for_portal(:ai).count }, span: 2, variant: :mini, color: :cyan
    end

    row do
      cards_panel "LLM Management",
        span: 12,
        resources: [
          { resource_name: "llm_prompts", label: "LLM Prompts", description: "Manage prompt templates for AI models", icon: "scroll-text", count: -> { ::Ai::LlmPrompt.count } },
          { resource_name: "llm_provider_configs", label: "Provider Configs", description: "Configure AI providers (OpenAI, Anthropic, etc)", icon: "sliders-horizontal", count: -> { ::LlmProviderConfig.count } },
          { resource_name: "llm_api_logs", label: "LLM API Logs", description: "Inspect API calls and errors", icon: "activity", count: -> { ::Ai::LlmApiLog.count } }
        ]
    end

    row do
      recent_panel "Recent API Calls",
        span: 6,
        scope: -> { ::Ai::LlmApiLog.order(created_at: :desc).limit(8) },
        view_all_path: ->(view) { view.resources_path(portal: :ai, resource_name: "llm_api_logs") }

      recent_panel "Recently Updated Prompts",
        span: 6,
        scope: -> { ::Ai::LlmPrompt.order(updated_at: :desc).limit(8) },
        view_all_path: ->(view) { view.resources_path(portal: :ai, resource_name: "llm_prompts") }
    end
  end
end
