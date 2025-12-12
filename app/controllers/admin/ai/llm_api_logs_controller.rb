# frozen_string_literal: true

module Admin
  module Ai
    # Controller for viewing LLM API logs
    #
    # Provides a filterable index of all LLM API calls and detailed
    # show views for debugging with full request/response payloads.
    class LlmApiLogsController < Admin::BaseController
      include Concerns::Paginatable

      before_action :set_log, only: [ :show ]

      # GET /admin/ai/llm_api_logs
      def index
        @pagy, @logs = paginate(filtered_logs)
        @stats = calculate_stats
        @filters = filter_params
      end

      # GET /admin/ai/llm_api_logs/:id
      def show
        @related_logs = find_related_logs
      end

      private

      # Sets the log from params
      def set_log
        @log = ::Ai::LlmApiLog.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        redirect_to admin_ai_llm_api_logs_path, alert: "LLM API log not found"
      end

      # Finds related logs based on the loggable object
      #
      # @return [ActiveRecord::Relation]
      def find_related_logs
        return [] unless @log.loggable.present?

        ::Ai::LlmApiLog
          .where(loggable: @log.loggable)
          .where.not(id: @log.id)
          .recent
          .limit(5)
      end

      # Returns filtered logs based on params
      #
      # @return [ActiveRecord::Relation] Filtered logs
      def filtered_logs
        logs = ::Ai::LlmApiLog.includes(:llm_prompt).recent

        # Filter by operation type
        logs = logs.by_operation(params[:operation_type]) if params[:operation_type].present?

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
        base = ::Ai::LlmApiLog.recent_period(7)

        {
          total: base.count,
          by_provider: base.group(:provider).count,
          by_status: base.group(:status).count,
          by_operation: base.group(:operation_type).count.transform_keys { |k| k.humanize },
          avg_latency: base.where.not(latency_ms: nil).average(:latency_ms).to_f.round(0),
          avg_confidence: (base.where.not(confidence_score: nil).average(:confidence_score).to_f * 100).round(1),
          total_cost: base.sum(:estimated_cost_cents).to_f / 100.0
        }
      end

      # Returns the current filter params
      #
      # @return [Hash] Filter params
      def filter_params
        params.permit(:provider, :status, :operation_type, :date_from, :date_to, :min_confidence, :max_confidence, :error_type)
      end
    end
  end
end
