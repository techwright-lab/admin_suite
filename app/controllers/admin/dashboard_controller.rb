# frozen_string_literal: true

module Admin
  # Dashboard controller for admin panel home page
  #
  # Provides an overview of system health and quick links to admin sections.
  class DashboardController < BaseController
    # GET /admin
    def index
      @stats = calculate_dashboard_stats
      @gmail_stats = calculate_gmail_stats
    end

    private

    # Calculates dashboard statistics
    #
    # @return [Hash] Dashboard stats
    def calculate_dashboard_stats
      {
        scraping_attempts_today: ScrapingAttempt.where("created_at > ?", Time.current.beginning_of_day).count,
        scraping_success_rate: calculate_success_rate,
        pending_extractions: ScrapingAttempt.where(status: [:pending, :fetching, :extracting]).count,
        failed_extractions: ScrapingAttempt.where(status: :failed).count,
        dead_letter_count: ScrapingAttempt.where(status: :dead_letter).count,
        ai_logs_today: ai_logs_today_count,
        total_job_listings: JobListing.count,
        active_job_listings: JobListing.where(status: :active).count
      }
    end

    # Calculates Gmail sync statistics
    #
    # @return [Hash] Gmail sync stats
    def calculate_gmail_stats
      {
        total_users: User.count,
        connected_users: ConnectedAccount.google.select(:user_id).distinct.count,
        sync_enabled_users: ConnectedAccount.google.sync_enabled.count,
        total_synced_emails: SyncedEmail.count,
        emails_today: SyncedEmail.where("created_at > ?", Time.current.beginning_of_day).count,
        needs_review: SyncedEmail.needs_review.count,
        processed: SyncedEmail.processed.count,
        email_senders: EmailSender.count,
        unassigned_senders: EmailSender.unassigned.count,
        recent_syncs: recent_sync_accounts
      }
    rescue StandardError => e
      Rails.logger.warn "Failed to calculate Gmail stats: #{e.message}"
      {}
    end

    # Returns accounts that synced recently
    #
    # @return [Array<Hash>]
    def recent_sync_accounts
      ConnectedAccount.google
                      .where.not(last_synced_at: nil)
                      .order(last_synced_at: :desc)
                      .limit(5)
                      .includes(:user)
                      .map do |account|
        {
          user_name: account.user.display_name,
          user_email: account.user.email_address,
          last_synced_at: account.last_synced_at,
          email_count: account.synced_emails.count,
          sync_enabled: account.sync_enabled?
        }
      end
    end

    # Calculates 7-day success rate
    #
    # @return [Float] Success rate percentage
    def calculate_success_rate
      recent = ScrapingAttempt.where("created_at > ?", 7.days.ago)
      return 0.0 if recent.count.zero?

      completed = recent.where(status: :completed).count
      (completed.to_f / recent.count * 100).round(1)
    end

    # Counts AI extraction logs from today
    #
    # @return [Integer] Count of today's AI logs
    def ai_logs_today_count
      return 0 unless defined?(AiExtractionLog)

      AiExtractionLog.where("created_at > ?", Time.current.beginning_of_day).count
    rescue
      0
    end
  end
end

