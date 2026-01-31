# frozen_string_literal: true

module Ai
  # Model for tracking all LLM API calls with full observability
  #
  # Stores detailed information about every LLM call including
  # full request/response payloads, token usage, costs, and performance metrics.
  # Supports polymorphic association to any loggable model.
  #
  # @example
  #   log = Ai::LlmApiLog.create!(
  #     operation_type: :job_extraction,
  #     loggable: job_listing,
  #     provider: "anthropic",
  #     model: "claude-sonnet-4-20250514",
  #     input_tokens: 5000,
  #     output_tokens: 500,
  #     latency_ms: 2500,
  #     status: :success
  #   )
  #
  class LlmApiLog < ApplicationRecord
    self.table_name = "llm_api_logs"

    # Provider cost per 1K tokens (in cents)
    # Updated as of 2024 pricing
    PROVIDER_COSTS = {
      "anthropic" => {
        "claude-sonnet-4-20250514" => { input: 0.3, output: 1.5 },
        "claude-3-5-sonnet-20241022" => { input: 0.3, output: 1.5 },
        "claude-3-haiku-20240307" => { input: 0.025, output: 0.125 }
      },
      "openai" => {
        "gpt-4o" => { input: 0.5, output: 1.5 },
        "gpt-4o-mini" => { input: 0.015, output: 0.06 },
        "gpt-4-turbo" => { input: 1.0, output: 3.0 }
      },
      "ollama" => {
        # Ollama is free (self-hosted)
        "default" => { input: 0.0, output: 0.0 }
      }
    }.freeze

    # Operation types for LLM calls
    OPERATION_TYPES = %w[
      job_extraction
      job_postprocess
      email_extraction
      resume_extraction
      interview_prep_match_analysis
      interview_prep_focus_areas
      interview_prep_question_framing
      interview_prep_strength_positioning
      assistant_chat
      assistant_tool_call
      signal_extraction
      email_facts_extraction
      interview_round_extraction
      round_feedback_extraction
      application_status_extraction
      round_prep_comprehensive
    ].freeze

    # Status values
    STATUSES = %i[
      success
      error
      timeout
      rate_limited
    ].freeze

    # Associations
    belongs_to :loggable, polymorphic: true, optional: true
    belongs_to :llm_prompt, class_name: "Ai::LlmPrompt", optional: true

    # Enum for status
    enum :status, {
      success: 0,
      error: 1,
      timeout: 2,
      rate_limited: 3
    }, default: :success

    # Validations
    validates :operation_type, presence: true, inclusion: { in: OPERATION_TYPES }
    validates :provider, presence: true
    validates :model, presence: true

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :by_provider, ->(provider) { where(provider: provider) }
    scope :by_status, ->(status) { where(status: status) }
    scope :by_operation, ->(operation_type) { where(operation_type: operation_type) }
    scope :successful, -> { where(status: :success) }
    scope :failed, -> { where.not(status: :success) }
    scope :with_errors, -> { where(status: [ :error, :timeout, :rate_limited ]) }
    scope :recent_period, ->(days = 7) { where("created_at > ?", days.days.ago) }
    scope :today, -> { where("created_at > ?", Time.current.beginning_of_day) }

    # Scopes for specific operations
    scope :job_extractions, -> { by_operation("job_extraction") }
    scope :email_extractions, -> { by_operation("email_extraction") }
    scope :resume_extractions, -> { by_operation("resume_extraction") }

    # Callbacks
    before_save :calculate_total_tokens
    before_save :calculate_estimated_cost

    # Returns formatted cost string
    #
    # @return [String] Formatted cost (e.g., "$0.0015")
    def formatted_cost
      return "N/A" if estimated_cost_cents.nil?
      return "Free" if estimated_cost_cents.zero?

      dollars = estimated_cost_cents / 100.0
      if dollars < 0.01
        format("$%.4f", dollars)
      else
        format("$%.2f", dollars)
      end
    end

    # Returns formatted latency string
    #
    # @return [String] Formatted latency (e.g., "2.5s")
    def formatted_latency
      return "N/A" if latency_ms.nil?

      if latency_ms < 1000
        "#{latency_ms}ms"
      else
        "#{(latency_ms / 1000.0).round(2)}s"
      end
    end

    # Returns formatted token usage
    #
    # @return [String] Formatted tokens (e.g., "5,000 in / 500 out")
    def formatted_tokens
      parts = []
      parts << "#{number_with_delimiter(input_tokens)} in" if input_tokens
      parts << "#{number_with_delimiter(output_tokens)} out" if output_tokens
      parts.any? ? parts.join(" / ") : "N/A"
    end

    # Returns the prompt text from request payload
    #
    # @return [String, nil] The prompt text or nil
    def prompt_text
      request_payload&.dig("prompt") || request_payload&.dig("messages", 0, "content")
    end

    # Returns the response text from response payload
    #
    # @return [String, nil] The response text or nil
    def response_text
      response_payload&.dig("content") || response_payload&.dig("text")
    end

    # Returns the list of successfully extracted field names
    #
    # @return [Array<String>] Field names
    def extracted_field_names
      Array(extracted_fields).map(&:to_s)
    end

    # Returns status badge color for UI
    #
    # @return [String] Color name
    def status_badge_color
      case status.to_sym
      when :success then "success"
      when :error then "danger"
      when :timeout then "warning"
      when :rate_limited then "info"
      else "neutral"
      end
    end

    # Returns operation type badge color for UI
    #
    # @return [String] Color name
    def operation_badge_color
      case operation_type
      when "job_extraction" then "blue"
      when "job_postprocess" then "blue"
      when "email_extraction" then "purple"
      when "resume_extraction" then "green"
      else "gray"
      end
    end

    # Returns human-readable operation type
    #
    # @return [String] Operation name
    def operation_type_name
      operation_type.humanize.titleize
    end

    # Class methods for aggregations
    class << self
      # Calculates total cost for a period
      #
      # @param days [Integer] Number of days
      # @return [Float] Total cost in dollars
      def total_cost_for_period(days = 7)
        recent_period(days).sum(:estimated_cost_cents).to_f / 100.0
      end

      # Calculates average latency for a period
      #
      # @param days [Integer] Number of days
      # @return [Float] Average latency in ms
      def average_latency_for_period(days = 7)
        recent_period(days).where.not(latency_ms: nil).average(:latency_ms).to_f.round(0)
      end

      # Calculates success rate for a period
      #
      # @param days [Integer] Number of days
      # @return [Float] Success rate percentage
      def success_rate_for_period(days = 7)
        logs = recent_period(days)
        return 0.0 if logs.count.zero?

        (logs.successful.count.to_f / logs.count * 100).round(1)
      end

      # Returns token usage breakdown by provider
      #
      # @param days [Integer] Number of days
      # @return [Array<Hash>] Usage by provider
      def token_usage_by_provider(days = 7)
        recent_period(days)
          .group(:provider)
          .select("provider, SUM(input_tokens) as total_input, SUM(output_tokens) as total_output, SUM(total_tokens) as total")
          .map do |result|
            {
              provider: result.provider,
              input_tokens: result.total_input.to_i,
              output_tokens: result.total_output.to_i,
              total_tokens: result.total.to_i
            }
          end
      end

      # Returns cost breakdown by provider
      #
      # @param days [Integer] Number of days
      # @return [Hash] Cost by provider
      def cost_by_provider(days = 7)
        recent_period(days)
          .group(:provider)
          .sum(:estimated_cost_cents)
          .transform_values { |v| (v.to_f / 100.0).round(4) }
      end

      # Returns cost breakdown by operation type
      #
      # @param days [Integer] Number of days
      # @return [Hash] Cost by operation
      def cost_by_operation(days = 7)
        recent_period(days)
          .group(:operation_type)
          .sum(:estimated_cost_cents)
          .transform_values { |v| (v.to_f / 100.0).round(4) }
      end

      # Returns error breakdown by type
      #
      # @param days [Integer] Number of days
      # @return [Hash] Error counts by type
      def error_breakdown(days = 7)
        recent_period(days)
          .with_errors
          .group(:status, :error_type)
          .count
      end

      # Returns counts by operation type
      #
      # @param days [Integer] Number of days
      # @return [Hash] Counts by operation
      def counts_by_operation(days = 7)
        recent_period(days)
          .group(:operation_type)
          .count
      end
    end

    private

    # Calculates total tokens from input and output
    def calculate_total_tokens
      self.total_tokens = (input_tokens || 0) + (output_tokens || 0)
    end

    # Calculates estimated cost based on provider pricing
    def calculate_estimated_cost
      return if provider.blank? || model.blank?

      provider_pricing = PROVIDER_COSTS.dig(provider.downcase)
      return unless provider_pricing

      # Try exact model match first, then default
      model_pricing = provider_pricing[model] || provider_pricing["default"]
      return unless model_pricing

      input_cost = ((input_tokens || 0) / 1000.0) * model_pricing[:input]
      output_cost = ((output_tokens || 0) / 1000.0) * model_pricing[:output]

      self.estimated_cost_cents = ((input_cost + output_cost) * 100).round
    end

    # Helper for number formatting
    def number_with_delimiter(number)
      return "0" if number.nil?

      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end
end
