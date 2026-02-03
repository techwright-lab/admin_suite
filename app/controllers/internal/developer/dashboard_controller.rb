# frozen_string_literal: true

module Internal
  module Developer
    # Dashboard controller for the developer portal
    #
    # Provides an overview of all registered resources, health metrics,
    # and quick access to different portals and sections.
    class DashboardController < BaseController
      before_action :load_resources!

      def index
        @resources_by_portal = build_resources_by_portal
        @stats = calculate_dashboard_stats
        @health = calculate_health_metrics
        @recent_activity = build_recent_activity
      end

      private

      # Loads all resource files (needed for Zeitwerk lazy loading)
      #
      # @return [void]
      def load_resources!
        # Skip if already loaded
        return if Admin::Base::Resource.registered_resources.any?

        # Load all resource definitions (require only loads once)
        Dir[Rails.root.join("app/admin/resources/*.rb").to_s].each do |file|
          require file
        end
      rescue NameError
        # Admin::Base::Resource not defined yet, load it first
        require "admin/base/resource"
        retry
      end

      # Groups resources by portal and section
      #
      # @return [Hash]
      def build_resources_by_portal
        resources = {}

        Admin::Base::Resource.registered_resources.each do |resource|
          portal = resource.portal_name || :other
          section = resource.section_name || :general

          resources[portal] ||= {}
          resources[portal][section] ||= []
          resources[portal][section] << resource
        end

        resources
      end

      # Calculates dashboard statistics
      #
      # @return [Hash]
      def calculate_dashboard_stats
        {
          total_resources: Admin::Base::Resource.registered_resources.count,
          portals: Admin::Base::Resource.registered_resources.map(&:portal_name).uniq.compact.count,
          ops_resources: Admin::Base::Resource.resources_for_portal(:ops).count,
          email_resources: Admin::Base::Resource.resources_for_portal(:email).count,
          ai_resources: Admin::Base::Resource.resources_for_portal(:ai).count,
          assistant_resources: Admin::Base::Resource.resources_for_portal(:assistant).count
        }
      end

      # Calculates health metrics for all systems
      #
      # @return [Hash]
      def calculate_health_metrics
        {
          scraping: scraping_health,
          llm: llm_health,
          assistant: assistant_health,
          app: app_health
        }
      end

      # Scraping system health
      def scraping_health
        recent_attempts = ScrapingAttempt.where("created_at > ?", 24.hours.ago)
        total = recent_attempts.count
        successful = recent_attempts.where(status: :completed).count
        failed = recent_attempts.where(status: :failed).count
        stuck = recent_attempts.where(status: :processing).where("updated_at < ?", 1.hour.ago).count

        success_rate = total > 0 ? (successful.to_f / total * 100).round : 0
        status = if stuck > 5 || (total > 10 && success_rate < 50)
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
      end

      # LLM API health
      def llm_health
        recent_logs = ::Ai::LlmApiLog.where("created_at > ?", 24.hours.ago)
        total = recent_logs.count
        successful = recent_logs.where(status: :success).count
        failed = recent_logs.where(status: :failed).count

        # Calculate average latency
        avg_latency = recent_logs.where(status: :success).average(:latency_ms)&.round || 0
        total_cost_cents = recent_logs.sum(:estimated_cost_cents) || 0
        total_cost = (total_cost_cents / 100.0).round(2)

        success_rate = total > 0 ? (successful.to_f / total * 100).round : 0
        status = if total > 10 && success_rate < 80
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
            "24h cost" => "$#{total_cost}"
          }
        }
      end

      # Assistant system health
      def assistant_health
        recent_threads = ::Assistant::ChatThread.where("created_at > ?", 24.hours.ago)
        recent_executions = ::Assistant::ToolExecution.where("created_at > ?", 24.hours.ago)

        total_threads = recent_threads.count
        total_executions = recent_executions.count
        pending_approvals = ::Assistant::ToolExecution.where(status: :pending_approval).count
        failed_executions = recent_executions.where(status: :failed).count

        status = if pending_approvals > 20 || failed_executions > 10
                   :degraded
        else
                   :healthy
        end

        {
          status: status,
          metrics: {
            "24h threads" => total_threads,
            "24h tool runs" => total_executions,
            "pending approval" => pending_approvals,
            "failed" => failed_executions
          }
        }
      end

      # Overall app health
      def app_health
        {
          status: :healthy,
          metrics: {
            "users" => User.count,
            "24h signups" => User.where("created_at > ?", 24.hours.ago).count,
            "applications" => InterviewApplication.count,
            "job listings" => JobListing.enabled.count
          }
        }
      end

      # Build recent activity feed
      #
      # @return [Hash]
      def build_recent_activity
        {
          recent_users: User.order(created_at: :desc).limit(5),
          recent_applications: InterviewApplication.includes(:user, :company).order(created_at: :desc).limit(5),
          recent_threads: ::Assistant::ChatThread.includes(:user).order(created_at: :desc).limit(5),
          recent_scraping: ScrapingAttempt.order(created_at: :desc).limit(5)
        }
      end
    end
  end
end
