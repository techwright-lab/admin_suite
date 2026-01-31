# frozen_string_literal: true

module Internal
  module Developer
    module Email
      # Dashboard for the Email Portal (Signals pipeline observability).
      class DashboardController < BaseController
        before_action :load_resources!

        # GET /internal/developer/email
        def index
          @stats = calculate_portal_stats
          @health = calculate_health_metrics
          @recent = build_recent_activity
        end

        private

        def calculate_portal_stats
          {
            total_emails: SyncedEmail.count,
            unmatched: SyncedEmail.unmatched.count,
            matched: SyncedEmail.matched.count,
            needs_review: SyncedEmail.needs_review.count,
            pipeline_runs_24h: Signals::EmailPipelineRun.where("created_at > ?", 24.hours.ago).count,
            pipeline_events_24h: Signals::EmailPipelineEvent.where("created_at > ?", 24.hours.ago).count
          }
        end

        def calculate_health_metrics
          recent_runs = Signals::EmailPipelineRun.where("created_at > ?", 24.hours.ago)
          total = recent_runs.count
          successful = recent_runs.where(status: :success).count
          failed = recent_runs.where(status: :failed).count
          running = recent_runs.where(status: :started).count

          success_rate = total.positive? ? (successful.to_f / total * 100).round : 0
          avg_duration = recent_runs.where.not(duration_ms: nil).average(:duration_ms)&.round || 0

          status =
            if failed > 10 || (total > 20 && success_rate < 80)
              :critical
            elsif failed.positive? || (total > 20 && success_rate < 95) || running > 20
              :degraded
            else
              :healthy
            end

          {
            status: status,
            metrics: {
              "24h runs" => total,
              "success rate" => "#{success_rate}%",
              "failed" => failed,
              "running" => running,
              "avg duration" => "#{avg_duration}ms"
            }
          }
        end

        def build_recent_activity
          {
            emails: SyncedEmail.order(email_date: :desc).limit(8),
            runs: Signals::EmailPipelineRun.order(created_at: :desc).limit(8)
          }
        end
      end
    end
  end
end
