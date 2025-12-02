# frozen_string_literal: true

module Admin
  # Controller for HTML scraping metrics dashboard and logs
  #
  # Provides an overview of HTML scraping performance across domains
  # and field-level extraction success rates.
  class HtmlScrapingLogsController < BaseController
    PER_PAGE = 25

    before_action :set_html_scraping_log, only: [ :show ]

    # GET /admin/html_scraping_logs
    def index
      @page = (params[:page] || 1).to_i
      @logs = filtered_logs.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      @total_count = filtered_logs.count
      @total_pages = (@total_count.to_f / PER_PAGE).ceil

      @overview_stats = calculate_overview_stats
      @domain_stats = calculate_domain_stats
      @field_stats = calculate_field_stats
      @filters = filter_params
    end

    # GET /admin/html_scraping_logs/:id
    def show
      @attempt = @log.scraping_attempt
      @job_listing = @log.job_listing
    end

    private

    # Sets the HTML scraping log from params
    def set_html_scraping_log
      @log = HtmlScrapingLog.includes(:scraping_attempt, :job_listing).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_html_scraping_logs_path, alert: "HTML scraping log not found"
    end

    # Returns filtered logs based on params
    #
    # @return [ActiveRecord::Relation] Filtered logs
    def filtered_logs
      logs = HtmlScrapingLog.includes(:scraping_attempt).recent

      logs = logs.by_domain(params[:domain]) if params[:domain].present?
      logs = logs.where(status: params[:status]) if params[:status].present?

      if params[:date_from].present?
        logs = logs.where("created_at >= ?", Date.parse(params[:date_from]).beginning_of_day)
      end
      if params[:date_to].present?
        logs = logs.where("created_at <= ?", Date.parse(params[:date_to]).end_of_day)
      end

      logs
    end

    # Returns the current filter params
    #
    # @return [Hash] Filter params
    def filter_params
      params.permit(:domain, :status, :date_from, :date_to)
    end

    # Calculates overview statistics
    #
    # @return [Hash] Overview stats
    def calculate_overview_stats
      base = HtmlScrapingLog.recent_period(7)

      {
        total_attempts: base.count,
        avg_extraction_rate: (base.average(:extraction_rate).to_f * 100).round(1),
        avg_duration_ms: base.average(:duration_ms).to_f.round(0),
        by_status: base.group(:status).count,
        success_rate: calculate_success_rate(base)
      }
    end

    # Calculates success rate
    #
    # @param [ActiveRecord::Relation] logs The logs
    # @return [Float] Success rate percentage
    def calculate_success_rate(logs)
      return 0.0 if logs.count.zero?

      successful = logs.where(status: [ :success, :partial ]).count
      (successful.to_f / logs.count * 100).round(1)
    end

    # Calculates per-domain statistics
    #
    # @return [Array<Hash>] Domain stats
    def calculate_domain_stats
      HtmlScrapingLog.recent_period(7)
                     .group(:domain)
                     .select(
                       "domain",
                       "COUNT(*) as total",
                       "AVG(extraction_rate) as avg_rate",
                       "AVG(duration_ms) as avg_duration",
                       "SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) as success_count",
                       "SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) as failed_count"
                     )
                     .order("total DESC")
                     .limit(10)
                     .map do |row|
        {
          domain: row.domain,
          total: row.total,
          avg_rate: (row.avg_rate.to_f * 100).round(1),
          avg_duration: row.avg_duration.to_f.round(0),
          success_count: row.success_count,
          failed_count: row.failed_count,
          success_rate: row.total > 0 ? (row.success_count.to_f / row.total * 100).round(1) : 0
        }
      end
    end

    # Calculates per-field extraction statistics
    #
    # @return [Hash] Field stats
    def calculate_field_stats
      stats = {}

      HtmlScrapingLog::TRACKED_FIELDS.each do |field|
        stats[field] = { total: 0, success: 0, rate: 0 }
      end

      # Sample recent logs for field analysis
      HtmlScrapingLog.recent_period(7).limit(1000).find_each do |log|
        next unless log.field_results.is_a?(Hash)

        log.field_results.each do |field, result|
          next unless stats.key?(field)
          next unless result.is_a?(Hash)

          stats[field][:total] += 1
          stats[field][:success] += 1 if result["success"]
        end
      end

      # Calculate rates
      stats.each do |field, data|
        data[:rate] = data[:total] > 0 ? (data[:success].to_f / data[:total] * 100).round(1) : 0
      end

      stats
    end
  end
end

