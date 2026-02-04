# frozen_string_literal: true

AdminSuite.portal :email do
  label "Email Portal"
  icon "inbox"
  color :emerald
  order 20
  description "Synced emails + Signals pipeline timeline"

  dashboard do
    row do
      health_panel "Signals Pipeline (24h)",
        span: 4,
        status: lambda {
          recent_runs = Signals::EmailPipelineRun.where("created_at > ?", 24.hours.ago)
          total = recent_runs.count
          successful = recent_runs.where(status: :success).count
          failed = recent_runs.where(status: :failed).count
          running = recent_runs.where(status: :started).count
          success_rate = total.positive? ? (successful.to_f / total * 100).round : 0

          if failed > 10 || (total > 20 && success_rate < 80)
            :critical
          elsif failed.positive? || (total > 20 && success_rate < 95) || running > 20
            :degraded
          else
            :healthy
          end
        },
        metrics: lambda {
          recent_runs = Signals::EmailPipelineRun.where("created_at > ?", 24.hours.ago)
          total = recent_runs.count
          successful = recent_runs.where(status: :success).count
          failed = recent_runs.where(status: :failed).count
          running = recent_runs.where(status: :started).count

          success_rate = total.positive? ? (successful.to_f / total * 100).round : 0
          avg_duration = recent_runs.where.not(duration_ms: nil).average(:duration_ms)&.round || 0

          {
            "24h runs" => total,
            "success rate" => "#{success_rate}%",
            "failed" => failed,
            "running" => running,
            "avg duration" => "#{avg_duration}ms"
          }
        }

      stat_panel "Synced Emails",
        -> { SyncedEmail.count },
        span: 4,
        color: :green

      stat_panel "Pipeline Runs (24h)",
        -> { Signals::EmailPipelineRun.where("created_at > ?", 24.hours.ago).count },
        span: 4,
        color: :cyan
    end

    row do
      stat_panel "Matched", -> { SyncedEmail.matched.count }, span: 2, variant: :mini, color: :green
      stat_panel "Unmatched", -> { SyncedEmail.unmatched.count }, span: 2, variant: :mini, color: :amber
      stat_panel "Needs Review", -> { SyncedEmail.needs_review.count }, span: 2, variant: :mini, color: :red
      stat_panel "Runs (24h)", -> { Signals::EmailPipelineRun.where("created_at > ?", 24.hours.ago).count }, span: 2, variant: :mini, color: :slate
      stat_panel "Events (24h)", -> { Signals::EmailPipelineEvent.where("created_at > ?", 24.hours.ago).count }, span: 2, variant: :mini, color: :slate
      stat_panel "Resources", -> { Admin::Base::Resource.resources_for_portal(:email).count }, span: 2, variant: :mini, color: :emerald
    end

    row do
      recent_panel "Recent Emails",
        span: 7,
        scope: -> { SyncedEmail.order(email_date: :desc).limit(8) },
        view_all_path: ->(view) { view.resources_path(portal: :email, resource_name: "synced_emails") }

      recent_panel "Recent Pipeline Runs",
        span: 5,
        scope: -> { Signals::EmailPipelineRun.order(created_at: :desc).limit(8) },
        view_all_path: ->(view) { view.resources_path(portal: :email, resource_name: "email_pipeline_runs") }
    end
  end
end
