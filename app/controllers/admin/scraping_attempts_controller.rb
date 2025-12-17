# frozen_string_literal: true

module Admin
  # Controller for viewing scraping attempts with full observability
  #
  # Provides index with filters and detailed show view with event timeline
  # and data comparison for debugging the scraping pipeline.
  #
  # Admin actions:
  # - mark_failed: Manually mark a stuck attempt as failed
  # - retry_attempt: Retry a failed attempt
  # - cleanup_stuck: Run cleanup job for all stuck attempts
  class ScrapingAttemptsController < BaseController
    include Concerns::Paginatable

    before_action :set_scraping_attempt, only: [ :show, :mark_failed, :retry_attempt ]

    # GET /admin/scraping_attempts
    def index
      @pagy, @attempts = paginate(filtered_attempts)
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/scraping_attempts/:id
    def show
      @events = @attempt.scraping_events.in_order
      @ai_logs = @attempt.llm_api_logs.order(created_at: :desc).limit(10)
      @scraped_data = @attempt.scraped_job_listing_data
      @job_listing = @attempt.job_listing
    @html_scraping_logs = @attempt.html_scraping_logs.order(created_at: :desc)
      @timeline_stats = calculate_timeline_stats(@events)
    end

    # POST /admin/scraping_attempts/:id/mark_failed
    # Manually marks a stuck attempt as failed
    def mark_failed
      if @attempt.completed? || @attempt.failed?
        redirect_to admin_scraping_attempt_path(@attempt), alert: "Attempt already in final state (#{@attempt.status})"
        return
      end

      # Find any incomplete events and mark them as failed
      @attempt.scraping_events.where(status: :started).find_each do |event|
        event.update!(
          status: :failed,
          completed_at: Time.current,
          error_type: "ManuallyMarkedFailed",
          error_message: "Manually marked as failed by admin"
        )
      end

      @attempt.update!(
        status: :failed,
        failed_step: @attempt.status,
        error_message: "Manually marked as failed by admin at #{Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')}"
      )

      redirect_to admin_scraping_attempt_path(@attempt), notice: "Attempt marked as failed"
    end

    # POST /admin/scraping_attempts/:id/retry
    # Queues a retry job for a failed attempt
    def retry_attempt
      unless @attempt.failed?
        redirect_to admin_scraping_attempt_path(@attempt), alert: "Can only retry failed attempts"
        return
      end

      # Queue a new scraping job
      ScrapeJobListingJob.perform_later(@attempt.job_listing)

      redirect_to admin_scraping_attempt_path(@attempt), notice: "Retry job queued for job listing ##{@attempt.job_listing_id}"
    end

    # POST /admin/scraping_attempts/cleanup_stuck
    # Runs the cleanup job for all stuck attempts
    def cleanup_stuck
      # Find how many would be cleaned up
      stuck_count = ScrapingAttempt
        .where(status: %w[pending fetching extracting retrying])
        .where("updated_at < ?", 10.minutes.ago)
        .count

      if stuck_count.zero?
        redirect_to admin_scraping_attempts_path, notice: "No stuck attempts found"
        return
      end

      # Run the cleanup job
      CleanupStuckScrapingAttemptsJob.perform_later

      redirect_to admin_scraping_attempts_path, notice: "Cleanup job queued for #{stuck_count} stuck attempt(s)"
    end

    private

    # Sets the scraping attempt from params
    def set_scraping_attempt
    @attempt = ScrapingAttempt.includes(:job_listing, :scraping_events, :llm_api_logs, :scraped_job_listing_data, :html_scraping_logs).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_scraping_attempts_path, alert: "Scraping attempt not found"
    end

    # Returns filtered attempts based on params
    #
    # @return [ActiveRecord::Relation] Filtered attempts
    def filtered_attempts
      attempts = ScrapingAttempt.includes(:job_listing).recent

      # Filter by status
      attempts = attempts.by_status(params[:status]) if params[:status].present?

      # Filter by domain
      attempts = attempts.by_domain(params[:domain]) if params[:domain].present?

      # Filter by extraction method
      attempts = attempts.where(extraction_method: params[:extraction_method]) if params[:extraction_method].present?

      # Filter by provider
      attempts = attempts.where(provider: params[:provider]) if params[:provider].present?

      # Filter by date range
      if params[:date_from].present?
        attempts = attempts.where("created_at >= ?", Date.parse(params[:date_from]).beginning_of_day)
      end
      if params[:date_to].present?
        attempts = attempts.where("created_at <= ?", Date.parse(params[:date_to]).end_of_day)
      end

      # Filter by has_events (only show attempts that have been recorded)
      if params[:has_events] == "true"
        attempts = attempts.joins(:scraping_events).distinct
      end

      attempts
    end

    # Calculates quick stats for the filter sidebar
    #
    # @return [Hash] Stats
    def calculate_stats
      base = ScrapingAttempt.recent_period(7)

      {
        total: base.count,
        by_status: base.group(:status).count,
        by_method: base.group(:extraction_method).count.compact,
        avg_duration: base.where.not(duration_seconds: nil).average(:duration_seconds).to_f.round(2),
        success_rate: calculate_success_rate(base),
        top_domains: base.group(:domain).count.sort_by { |_, v| -v }.first(5).to_h
      }
    end

    # Calculates success rate
    #
    # @param [ActiveRecord::Relation] attempts The attempts
    # @return [Float] Success rate percentage
    def calculate_success_rate(attempts)
      return 0.0 if attempts.count.zero?

      completed = attempts.where(status: :completed).count
      (completed.to_f / attempts.count * 100).round(1)
    end

    # Returns the current filter params
    #
    # @return [Hash] Filter params
    def filter_params
      params.permit(:status, :domain, :extraction_method, :provider, :date_from, :date_to, :has_events)
    end

    # Calculates timeline statistics from events
    #
    # @param [Array<ScrapingEvent>] events The events
    # @return [Hash] Timeline stats
    def calculate_timeline_stats(events)
      return {} if events.empty?

      # Handle nil duration_ms values safely
      total_duration = events.sum { |e| e.duration_ms || 0 }
      successful = events.select(&:success?)
      failed = events.select(&:failed?)

      {
        total_steps: events.count,
        successful_steps: successful.count,
        failed_steps: failed.count,
        skipped_steps: events.select(&:skipped?).count,
        total_duration_ms: total_duration,
        slowest_step: events.max_by { |e| e.duration_ms || 0 },
        first_failure: failed.first
      }
    end
  end
end
