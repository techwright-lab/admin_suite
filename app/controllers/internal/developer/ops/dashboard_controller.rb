# frozen_string_literal: true

module Internal
  module Developer
    module Ops
      # Dashboard for the Ops Portal
      class DashboardController < BaseController
        before_action :load_resources!

        # GET /internal/developer/ops
        def index
          @resources_by_section = build_resources_by_section
          @stats = calculate_portal_stats
          @health = calculate_health_metrics
          @recent = build_recent_activity
          @charts = build_chart_data
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
            companies: Company.count,
            job_roles: JobRole.count,
            categories: Category.count,
            skill_tags: SkillTag.count,
            users: User.count,
            applications: InterviewApplication.count,
            job_listings: JobListing.count
          }
        end

        def calculate_health_metrics
          {
            scraping: scraping_health,
            email_sync: email_sync_health
          }
        end

        def scraping_health
          recent = ScrapingAttempt.where("created_at > ?", 24.hours.ago)
          total = recent.count
          completed = recent.where(status: :completed).count
          failed = recent.where(status: :failed).count
          stuck = recent.where(status: :processing).where("updated_at < ?", 30.minutes.ago).count

          rate = total > 0 ? (completed.to_f / total * 100).round : 0
          status = if stuck > 5 || (total > 10 && rate < 50)
                     :critical
                   elsif stuck > 0 || (total > 10 && rate < 80)
                     :degraded
                   else
                     :healthy
                   end

          { status: status, total: total, completed: completed, failed: failed, stuck: stuck, rate: rate }
        end

        def email_sync_health
          recent = SyncedEmail.where("created_at > ?", 24.hours.ago)
          total = recent.count
          pending = SyncedEmail.where(status: :needs_review).count
          processed = recent.where(status: :processed).count

          { total: total, pending: pending, processed: processed }
        end

        def build_recent_activity
          {
            users: User.order(created_at: :desc).limit(5),
            applications: InterviewApplication.includes(:user, :company).order(created_at: :desc).limit(5),
            job_listings: JobListing.includes(:company).order(created_at: :desc).limit(5),
            scraping: ScrapingAttempt.order(created_at: :desc).limit(5)
          }
        end

        def build_chart_data
          # Last 7 days of scraping attempts
          scraping_by_day = (0..6).map do |i|
            date = i.days.ago.to_date
            count = ScrapingAttempt.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse

          # Last 7 days of signups
          signups_by_day = (0..6).map do |i|
            date = i.days.ago.to_date
            count = User.where(created_at: date.beginning_of_day..date.end_of_day).count
            { label: date.strftime("%a"), value: count }
          end.reverse

          { scraping: scraping_by_day, signups: signups_by_day }
        end
      end
    end
  end
end

