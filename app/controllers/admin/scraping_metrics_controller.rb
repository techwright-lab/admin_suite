# frozen_string_literal: true

module Admin
  # Controller for scraping metrics dashboard
  class ScrapingMetricsController < BaseController

    # GET /admin/scraping_metrics
    def index
      @metrics = calculate_metrics
      @ai_metrics = calculate_ai_metrics
      @chart_data = prepare_chart_data
    end

    private

    # Calculates all metrics for the dashboard
    #
    # @return [Hash] Metrics data
    def calculate_metrics
      {
        overview: overview_metrics,
        by_domain: domain_metrics,
        recent_failures: recent_failures,
        dlq_count: dlq_count,
        provider_performance: provider_performance
      }
    end

    # Calculates AI-specific metrics
    #
    # @return [Hash] AI metrics data
    def calculate_ai_metrics
      return {} unless defined?(Ai::LlmApiLog)

      {
        overview: ai_overview_metrics,
        by_provider: ai_provider_metrics,
        cost_breakdown: ai_cost_breakdown,
        error_breakdown: ai_error_breakdown,
        recent_logs: recent_ai_logs
      }
    rescue => e
      Rails.logger.warn("Failed to calculate AI metrics: #{e.message}")
      {}
    end

    # Prepares chart data for visualizations
    #
    # @return [Hash] Chart data
    def prepare_chart_data
      return {} unless defined?(Ai::LlmApiLog)

      {
        ai_calls_over_time: ai_calls_over_time,
        cost_over_time: cost_over_time,
        latency_distribution: latency_distribution,
        confidence_distribution: confidence_distribution
      }
    rescue => e
      Rails.logger.warn("Failed to prepare chart data: #{e.message}")
      {}
    end

    # AI overview metrics
    #
    # @return [Hash] AI overview stats
    def ai_overview_metrics
      logs_7d = Ai::LlmApiLog.where("created_at > ?", 7.days.ago)
      logs_today = Ai::LlmApiLog.where("created_at > ?", Time.current.beginning_of_day)

      success_count = logs_7d.where(status: :success).count
      success_rate = logs_7d.count > 0 ? (success_count.to_f / logs_7d.count * 100).round(1) : 0

      {
        total_calls_7d: logs_7d.count,
        calls_today: logs_today.count,
        success_rate_7d: success_rate,
        total_cost_7d: (logs_7d.sum(:estimated_cost_cents).to_f / 100).round(4),
        avg_latency_7d: logs_7d.average(:latency_ms).to_f.round(0),
        total_tokens_7d: logs_7d.sum(:total_tokens)
      }
    end

    # AI metrics by provider
    #
    # @return [Array<Hash>] Metrics per provider
    def ai_provider_metrics
      Ai::LlmApiLog.where("created_at > ?", 7.days.ago)
        .group(:provider)
        .select("provider,
                 COUNT(*) as total_calls,
                 SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) as successful_calls,
                 AVG(latency_ms) as avg_latency,
                 AVG(confidence_score) as avg_confidence,
                 SUM(estimated_cost_cents) as total_cost_cents,
                 SUM(total_tokens) as total_tokens")
        .map do |result|
          {
            provider: result.provider,
            total_calls: result.total_calls,
            success_rate: result.total_calls > 0 ? (result.successful_calls.to_f / result.total_calls * 100).round(1) : 0,
            avg_latency_ms: result.avg_latency.to_f.round(0),
            avg_confidence: (result.avg_confidence.to_f * 100).round(1),
            total_cost: (result.total_cost_cents.to_f / 100).round(4),
            total_tokens: result.total_tokens.to_i
          }
        end
    end

    # AI cost breakdown by provider
    #
    # @return [Hash] Cost by provider
    def ai_cost_breakdown
      Ai::LlmApiLog.where("created_at > ?", 7.days.ago)
        .group(:provider)
        .sum(:estimated_cost_cents)
        .transform_values { |v| (v.to_f / 100).round(4) }
    end

    # AI error breakdown
    #
    # @return [Hash] Error counts by type
    def ai_error_breakdown
      Ai::LlmApiLog.where("created_at > ?", 7.days.ago)
        .where.not(status: :success)
        .group(:status)
        .count
        .transform_keys { |k| Ai::LlmApiLog.statuses.key(k) || k }
    end

    # Recent AI extraction logs
    #
    # @return [ActiveRecord::Relation] Recent AI logs
    def recent_ai_logs
      Ai::LlmApiLog
        .includes(:loggable)
        .order(created_at: :desc)
        .limit(10)
    end

    # AI calls over time for chart
    #
    # @return [Hash] Daily call counts
    def ai_calls_over_time
      Ai::LlmApiLog.where("created_at > ?", 14.days.ago)
        .group_by_day(:created_at)
        .count
    end

    # Cost over time for chart
    #
    # @return [Hash] Daily costs
    def cost_over_time
      Ai::LlmApiLog.where("created_at > ?", 14.days.ago)
        .group_by_day(:created_at)
        .sum(:estimated_cost_cents)
        .transform_values { |v| (v.to_f / 100).round(4) }
    end

    # Latency distribution for chart
    #
    # @return [Hash] Latency buckets
    def latency_distribution
      logs_7d = Ai::LlmApiLog.where("created_at > ?", 7.days.ago)
      {
        "< 1s" => logs_7d.where("latency_ms < 1000").count,
        "1-2s" => logs_7d.where("latency_ms >= 1000 AND latency_ms < 2000").count,
        "2-5s" => logs_7d.where("latency_ms >= 2000 AND latency_ms < 5000").count,
        "5-10s" => logs_7d.where("latency_ms >= 5000 AND latency_ms < 10000").count,
        "> 10s" => logs_7d.where("latency_ms >= 10000").count
      }
    end

    # Confidence distribution for chart
    #
    # @return [Hash] Confidence buckets
    def confidence_distribution
      logs_7d = Ai::LlmApiLog.where("created_at > ?", 7.days.ago)
      {
        "0-50%" => logs_7d.where("confidence_score < 0.5").count,
        "50-70%" => logs_7d.where("confidence_score >= 0.5 AND confidence_score < 0.7").count,
        "70-85%" => logs_7d.where("confidence_score >= 0.7 AND confidence_score < 0.85").count,
        "85-95%" => logs_7d.where("confidence_score >= 0.85 AND confidence_score < 0.95").count,
        "95-100%" => logs_7d.where("confidence_score >= 0.95").count
      }
    end

    # Overview metrics
    #
    # @return [Hash] Overview stats
    def overview_metrics
      total = ScrapingAttempt.count
      last_7_days = ScrapingAttempt.recent_period(7)
      
      {
        total_attempts: total,
        last_7_days: last_7_days.count,
        success_rate_7d: calculate_success_rate(last_7_days),
        avg_duration: calculate_avg_duration(last_7_days),
        dlq_count: ScrapingAttempt.where(status: :dead_letter).count,
        pending_count: ScrapingAttempt.where(status: [:pending, :retrying]).count
      }
    end

    # Domain-specific metrics
    #
    # @return [Array<Hash>] Metrics per domain
    def domain_metrics
      ScrapingAttempt.recent_period(30)
        .group(:domain)
        .count
        .map do |domain, count|
          domain_attempts = ScrapingAttempt.by_domain(domain).recent_period(7)
          
          {
            domain: domain,
            attempts_7d: domain_attempts.count,
            success_rate: calculate_success_rate(domain_attempts),
            avg_duration: calculate_avg_duration(domain_attempts)
          }
        end
        .sort_by { |m| -m[:attempts_7d] }
        .first(10)
    end

    # Recent failures needing attention
    #
    # @return [ActiveRecord::Relation] Failed attempts
    def recent_failures
      ScrapingAttempt
        .includes(:job_listing)
        .where(status: [:failed, :dead_letter])
        .order(created_at: :desc)
        .limit(20)
    end

    # Count of items in DLQ
    #
    # @return [Integer] DLQ count
    def dlq_count
      ScrapingAttempt.where(status: :dead_letter).count
    end

    # Provider performance comparison
    #
    # @return [Hash] Performance by provider
    def provider_performance
      ScrapingAttempt.recent_period(30)
        .where.not(provider: nil)
        .group(:provider)
        .select('provider, 
                 COUNT(*) as total,
                 AVG(confidence_score) as avg_confidence,
                 AVG(duration_seconds) as avg_duration')
        .map do |result|
          {
            provider: result.provider,
            total: result.total,
            avg_confidence: (result.avg_confidence.to_f * 100).round(1),
            avg_duration: result.avg_duration.to_f.round(2)
          }
        end
    end

    # Calculates success rate for a collection
    #
    # @param [ActiveRecord::Relation] attempts The attempts
    # @return [Float] Success rate percentage
    def calculate_success_rate(attempts)
      return 0.0 if attempts.count.zero?

      completed = attempts.where(status: :completed).count
      (completed.to_f / attempts.count * 100).round(1)
    end

    # Calculates average duration
    #
    # @param [ActiveRecord::Relation] attempts The attempts
    # @return [Float] Average duration in seconds
    def calculate_avg_duration(attempts)
      attempts.where.not(duration_seconds: nil).average(:duration_seconds).to_f.round(2)
    end
  end
end

