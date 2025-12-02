# frozen_string_literal: true

module Admin
  # Controller for viewing AI extraction logs
  #
  # Provides a filterable index of all AI extraction calls and detailed
  # show views for debugging with full request/response payloads.
  class AiExtractionLogsController < BaseController
    PER_PAGE = 25

    before_action :set_ai_extraction_log, only: [ :show ]

    # GET /admin/ai_extraction_logs
    def index
      @page = (params[:page] || 1).to_i
      @logs = filtered_logs.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      @total_count = filtered_logs.count
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @stats = calculate_stats
      @filters = filter_params
    end

    # GET /admin/ai_extraction_logs/:id
    def show
      @related_logs = @log.job_listing&.ai_extraction_logs&.where&.not(id: @log.id)&.recent&.limit(5) || []
    end

    private

    # Sets the AI extraction log from params
    def set_ai_extraction_log
      @log = AiExtractionLog.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_ai_extraction_logs_path, alert: "AI extraction log not found"
    end

    # Returns filtered logs based on params
    #
    # @return [ActiveRecord::Relation] Filtered logs
    def filtered_logs
      logs = AiExtractionLog.includes(:job_listing, :scraping_attempt).recent

      # Filter by provider
      logs = logs.by_provider(params[:provider]) if params[:provider].present?

      # Filter by status
      logs = logs.by_status(params[:status]) if params[:status].present?

      # Filter by date range
      if params[:date_from].present?
        logs = logs.where("created_at >= ?", Date.parse(params[:date_from]).beginning_of_day)
      end
      if params[:date_to].present?
        logs = logs.where("created_at <= ?", Date.parse(params[:date_to]).end_of_day)
      end

      # Filter by confidence
      if params[:min_confidence].present?
        logs = logs.where("confidence_score >= ?", params[:min_confidence].to_f)
      end
      if params[:max_confidence].present?
        logs = logs.where("confidence_score <= ?", params[:max_confidence].to_f)
      end

      # Filter by error type
      logs = logs.where(error_type: params[:error_type]) if params[:error_type].present?

      logs
    end

    # Calculates quick stats for the filter sidebar
    #
    # @return [Hash] Stats
    def calculate_stats
      base = AiExtractionLog.recent_period(7)

      {
        total: base.count,
        by_provider: base.group(:provider).count,
        by_status: base.group(:status).count,
        avg_latency: base.where.not(latency_ms: nil).average(:latency_ms).to_f.round(0),
        avg_confidence: (base.where.not(confidence_score: nil).average(:confidence_score).to_f * 100).round(1)
      }
    end

    # Returns the current filter params
    #
    # @return [Hash] Filter params
    def filter_params
      params.permit(:provider, :status, :date_from, :date_to, :min_confidence, :max_confidence, :error_type)
    end
  end
end

