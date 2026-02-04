# frozen_string_literal: true

module AdminSuite
  class DashboardController < ApplicationController
    def index
      # Ensure portal/resource metadata is available.
      items = navigation_items

      @health = build_root_health
      @stats = build_root_stats(items)
      @recent = build_root_recent

      @portal_cards =
        items.sort_by { |(_k, v)| (v[:order] || 100).to_i }.map do |portal_key, portal|
          color = portal[:color].presence || default_portal_color(portal_key)
          {
            key: portal_key,
            label: portal[:label] || portal_key.to_s.humanize,
            description: portal[:description],
            color: color,
            icon: portal[:icon],
            path: portal_path(portal: portal_key),
            count: portal[:sections].values.sum { |s| s[:items].size }
          }
        end

      @dashboard_sections = build_sections
    end

    private

    def default_portal_color(portal_key)
      case portal_key.to_sym
      when :ops then "amber"
      when :email then "emerald"
      when :ai then "cyan"
      when :assistant then "violet"
      when :payments then "emerald"
      else "slate"
      end
    end

    def build_sections
      sections = []

      sections << {
        title: "System Health",
        subtitle: nil,
        rows: [
          AdminSuite::UI::RowDefinition.new(panels: [
            AdminSuite::UI::PanelDefinition.new(type: :health, title: "Application", options: { span: 3, status: @health.dig(:app, :status), metrics: @health.dig(:app, :metrics) }),
            AdminSuite::UI::PanelDefinition.new(type: :health, title: "Scraping Pipeline", options: { span: 3, status: @health.dig(:scraping, :status), metrics: @health.dig(:scraping, :metrics) }),
            AdminSuite::UI::PanelDefinition.new(type: :health, title: "LLM API", options: { span: 3, status: @health.dig(:llm, :status), metrics: @health.dig(:llm, :metrics) }),
            AdminSuite::UI::PanelDefinition.new(type: :health, title: "Assistant", options: { span: 3, status: @health.dig(:assistant, :status), metrics: @health.dig(:assistant, :metrics) })
          ])
        ]
      }

      sections << {
        title: nil,
        subtitle: nil,
        rows: [
          AdminSuite::UI::RowDefinition.new(panels: [
            AdminSuite::UI::PanelDefinition.new(
              type: :cards,
              title: "Portals",
              options: { span: 12, variant: :portals, resources: @portal_cards }
            )
          ])
        ]
      }

      sections << {
        title: nil,
        subtitle: nil,
        rows: [
          AdminSuite::UI::RowDefinition.new(panels: [
            AdminSuite::UI::PanelDefinition.new(type: :stat, title: "Total Resources", options: { span: 3, variant: :mini, color: :slate, value: @stats[:total_resources] }),
            AdminSuite::UI::PanelDefinition.new(type: :stat, title: "Ops Resources", options: { span: 3, variant: :mini, color: :amber, value: @stats[:ops_resources] }),
            AdminSuite::UI::PanelDefinition.new(type: :stat, title: "Email Resources", options: { span: 2, variant: :mini, color: :emerald, value: @stats[:email_resources] }),
            AdminSuite::UI::PanelDefinition.new(type: :stat, title: "AI Resources", options: { span: 2, variant: :mini, color: :cyan, value: @stats[:ai_resources] }),
            AdminSuite::UI::PanelDefinition.new(type: :stat, title: "Assistant Resources", options: { span: 2, variant: :mini, color: :violet, value: @stats[:assistant_resources] })
          ])
        ]
      }

      sections << {
        title: "Recent Activity",
        subtitle: nil,
        rows: [
          AdminSuite::UI::RowDefinition.new(panels: [
            AdminSuite::UI::PanelDefinition.new(type: :recent, title: "Recent Signups", options: { span: 3, scope: @recent[:recent_users], view_all_path: ->(view) { view.resources_path(portal: :ops, resource_name: "users") } }),
            AdminSuite::UI::PanelDefinition.new(type: :recent, title: "Recent Applications", options: { span: 3, scope: @recent[:recent_applications], view_all_path: ->(view) { view.resources_path(portal: :ops, resource_name: "interview_applications") } }),
            AdminSuite::UI::PanelDefinition.new(type: :recent, title: "Recent Assistant", options: { span: 3, scope: @recent[:recent_threads], view_all_path: ->(view) { view.resources_path(portal: :assistant, resource_name: "assistant_threads") } }),
            AdminSuite::UI::PanelDefinition.new(type: :recent, title: "Recent Scraping", options: { span: 3, scope: @recent[:recent_scraping], view_all_path: ->(view) { view.resources_path(portal: :ops, resource_name: "scraping_attempts") } })
          ])
        ]
      }

      sections
    end

    def build_root_stats(items)
      {
        total_resources: Admin::Base::Resource.registered_resources.count,
        portals: items.keys.count,
        ops_resources: Admin::Base::Resource.resources_for_portal(:ops).count,
        email_resources: Admin::Base::Resource.resources_for_portal(:email).count,
        ai_resources: Admin::Base::Resource.resources_for_portal(:ai).count,
        assistant_resources: Admin::Base::Resource.resources_for_portal(:assistant).count
      }
    rescue StandardError
      { total_resources: 0, portals: 0, ops_resources: 0, email_resources: 0, ai_resources: 0, assistant_resources: 0 }
    end

    def build_root_recent
      {
        recent_users: -> { defined?(::User) ? ::User.order(created_at: :desc).limit(5) : [] },
        recent_applications: -> { defined?(::InterviewApplication) ? ::InterviewApplication.order(created_at: :desc).limit(5) : [] },
        recent_threads: -> { defined?(::Assistant::ChatThread) ? ::Assistant::ChatThread.order(created_at: :desc).limit(5) : [] },
        recent_scraping: -> { defined?(::ScrapingAttempt) ? ::ScrapingAttempt.order(created_at: :desc).limit(5) : [] }
      }
    end

    def build_root_health
      {
        app: app_health,
        scraping: scraping_health,
        llm: llm_health,
        assistant: assistant_health
      }
    end

    def app_health
      return { status: :unknown, metrics: {} } unless defined?(::User)

      metrics = {
        "Users" => safe_count(::User),
        "24h signups" => safe_count(::User, ->(rel) { rel.where("created_at > ?", 24.hours.ago) }),
        "Applications" => (defined?(::InterviewApplication) ? safe_count(::InterviewApplication) : "—"),
        "Job listings" => (defined?(::JobListing) ? safe_count(::JobListing) : "—")
      }

      { status: :healthy, metrics: metrics }
    rescue StandardError
      { status: :unknown, metrics: {} }
    end

    def scraping_health
      return { status: :unknown, metrics: {} } unless defined?(::ScrapingAttempt)

      recent_attempts = ::ScrapingAttempt.where("created_at > ?", 24.hours.ago)
      total = recent_attempts.count
      successful = recent_attempts.where(status: :completed).count
      failed = recent_attempts.where(status: :failed).count
      stuck = recent_attempts.where(status: :processing).where("updated_at < ?", 1.hour.ago).count

      success_rate = total > 0 ? (successful.to_f / total * 100).round : 0
      status =
        if stuck > 5 || (total > 10 && success_rate < 50)
          :critical
        elsif stuck > 0 || (total > 10 && success_rate < 80)
          :degraded
        else
          :healthy
        end

      {
        status: status,
        metrics: {
          "24h attempts" => total,
          "success rate" => "#{success_rate}%",
          "failed" => failed,
          "stuck" => stuck
        }
      }
    rescue StandardError
      { status: :unknown, metrics: {} }
    end

    def llm_health
      return { status: :unknown, metrics: {} } unless defined?(::Ai::LlmApiLog)

      recent_logs = ::Ai::LlmApiLog.where("created_at > ?", 24.hours.ago)
      total = recent_logs.count
      successful = recent_logs.where(status: :success).count
      failed = recent_logs.where(status: :failed).count
      avg_latency = recent_logs.where(status: :success).average(:latency_ms)&.round || 0
      total_cost_cents = recent_logs.sum(:estimated_cost_cents) || 0
      total_cost = (total_cost_cents / 100.0).round(2)

      success_rate = total > 0 ? (successful.to_f / total * 100).round : 0
      status =
        if total > 10 && success_rate < 80
          :critical
        elsif total > 10 && success_rate < 95
          :degraded
        else
          :healthy
        end

      {
        status: status,
        metrics: {
          "24h calls" => total,
          "success rate" => "#{success_rate}%",
          "avg latency" => "#{avg_latency}ms",
          "24h cost" => "$#{total_cost}",
          "failed" => failed
        }
      }
    rescue StandardError
      { status: :unknown, metrics: {} }
    end

    def assistant_health
      return { status: :unknown, metrics: {} } unless defined?(::Assistant::ToolExecution)

      recent_threads = (defined?(::Assistant::ChatThread) ? ::Assistant::ChatThread.where("created_at > ?", 24.hours.ago) : nil)
      recent_executions = ::Assistant::ToolExecution.where("created_at > ?", 24.hours.ago)

      total_executions = recent_executions.count
      successful = recent_executions.where(status: :completed).count
      failed = recent_executions.where(status: :failed).count
      pending = ::Assistant::ToolExecution.where(status: :pending_approval).count

      success_rate = total_executions > 0 ? (successful.to_f / total_executions * 100).round : 100
      status =
        if failed > 10
          :critical
        elsif pending > 20 || (total_executions > 10 && success_rate < 70)
          :degraded
        else
          :healthy
        end

      {
        status: status,
        metrics: {
          "24h threads" => (recent_threads ? recent_threads.count : "—"),
          "24h tool runs" => total_executions,
          "success rate" => "#{success_rate}%",
          "pending" => pending
        }
      }
    rescue StandardError
      { status: :unknown, metrics: {} }
    end

    def safe_count(klass, scope_proc = nil)
      rel = klass.all
      rel = scope_proc.call(rel) if scope_proc
      rel.count
    rescue StandardError
      "—"
    end
  end
end
