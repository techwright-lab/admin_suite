# frozen_string_literal: true

module Signals
  # Service for processing round feedback emails to update interview round results
  #
  # Processes emails classified as round_feedback to extract pass/fail results
  # and create InterviewFeedback records with detailed feedback.
  #
  # @example
  #   processor = Signals::RoundFeedbackProcessor.new(synced_email)
  #   result = processor.process
  #   if result[:success]
  #     # Round result updated and feedback created
  #   end
  #
  class RoundFeedbackProcessor < ApplicationService
    attr_reader :synced_email, :application

    # Email types that this processor handles
    PROCESSABLE_TYPES = %w[round_feedback].freeze

    # Minimum confidence score to accept extraction results
    MIN_CONFIDENCE_SCORE = 0.5

    # Operation type for logging
    OPERATION_TYPE = :round_feedback_extraction

    # Initialize the processor
    #
    # @param synced_email [SyncedEmail] The email to process
    def initialize(synced_email)
      @synced_email = synced_email
      @application = synced_email.interview_application
    end

    # Processes the email to update round result and create feedback
    #
    # @return [Hash] Result with success status
    def process
      Rails.logger.info("[RoundFeedbackProcessor] Processing email ##{synced_email.id}: #{synced_email.subject}")

      return skip_result("Email not matched to application") unless application
      return skip_result("Email type not processable") unless processable?
      return skip_result("No email content") unless content_available?

      # Extract feedback data using LLM
      extraction = extract_feedback_data
      unless extraction[:success]
        Rails.logger.warn("[RoundFeedbackProcessor] Extraction failed for email ##{synced_email.id}: #{extraction[:error]}")
        return { success: false, error: extraction[:error] }
      end

      data = extraction[:data]

      # Find matching round
      round = find_matching_round(data)

      if round
        update_round_with_feedback(round, data)
        Rails.logger.info("[RoundFeedbackProcessor] Updated round ##{round.id} result to #{round.result}")
        { success: true, round: round, action: :updated, llm_api_log_id: extraction[:llm_api_log_id] }
      else
        # Create a new round with the feedback result if we couldn't match
        round = create_round_from_feedback(data)
        if round&.persisted?
          Rails.logger.info("[RoundFeedbackProcessor] Created round ##{round.id} from feedback")
          { success: true, round: round, action: :created, llm_api_log_id: extraction[:llm_api_log_id] }
        else
          Rails.logger.warn("[RoundFeedbackProcessor] Could not find or create matching round")
          { success: false, error: "Could not find or create matching round" }
        end
      end
    rescue StandardError => e
      notify_error(
        e,
        context: "round_feedback_processor",
        user: synced_email&.user,
        synced_email_id: synced_email&.id,
        application_id: application&.id,
        email_type: synced_email&.email_type,
        company: application&.company&.name
      )
      Rails.logger.error("[RoundFeedbackProcessor] Error processing email ##{synced_email&.id}: #{e.message}")
      { success: false, error: e.message }
    end

    private

    # Checks if email type is processable
    #
    # @return [Boolean]
    def processable?
      PROCESSABLE_TYPES.include?(synced_email.email_type)
    end

    # Checks if email content is available
    #
    # @return [Boolean]
    def content_available?
      synced_email.body_preview.present? ||
        synced_email.body_html.present? ||
        synced_email.snippet.present?
    end

    # Returns skip result
    #
    # @param reason [String]
    # @return [Hash]
    def skip_result(reason)
      Rails.logger.info("[RoundFeedbackProcessor] Skipped email ##{synced_email&.id}: #{reason}")
      { success: false, skipped: true, reason: reason }
    end

    # Extracts feedback data using LLM with observability
    #
    # @return [Hash] Result with success and data
    def extract_feedback_data
      prompt = build_prompt
      prompt_template = Ai::RoundFeedbackExtractionPrompt.active_prompt
      system_message = prompt_template&.system_prompt.presence || Ai::RoundFeedbackExtractionPrompt.default_system_prompt

      runner = Ai::ProviderRunnerService.new(
        provider_chain: provider_chain,
        prompt: prompt,
        content_size: extract_body_content.bytesize,
        system_message: system_message,
        provider_for: method(:get_provider_instance),
        run_options: { max_tokens: 1500, temperature: 0.1 },
        logger_builder: lambda { |provider_name, provider|
          Ai::ApiLoggerService.new(
            operation_type: OPERATION_TYPE,
            loggable: synced_email,
            provider: provider_name,
            model: provider.respond_to?(:model_name) ? provider.model_name : "unknown",
            llm_prompt: prompt_template
          )
        },
        operation: OPERATION_TYPE,
        loggable: synced_email,
        user: synced_email&.user,
        error_context: {
          severity: "warning",
          synced_email_id: synced_email&.id,
          application_id: application&.id
        }
      )

      result = runner.run do |response|
        parsed = parse_response(response[:content])
        round_context = parsed[:round_context] || {}
        feedback = parsed[:feedback] || {}
        next_steps = parsed[:next_steps] || {}

        log_data = {
          confidence: parsed&.dig(:confidence_score),
          result: parsed[:result],
          sentiment: parsed[:sentiment],
          stage_mentioned: round_context[:stage_mentioned],
          interviewer_mentioned: round_context[:interviewer_mentioned],
          has_detailed_feedback: feedback[:has_detailed_feedback],
          has_next_round: next_steps[:has_next_round],
          extracted_fields: extract_field_names(parsed)
        }.compact

        confidence_score = parsed[:confidence_score]
        if confidence_score && confidence_score < MIN_CONFIDENCE_SCORE
          Rails.logger.warn("[RoundFeedbackProcessor] Low confidence (#{confidence_score}) from provider")
        end
        accept = confidence_score.nil? || confidence_score >= MIN_CONFIDENCE_SCORE
        [ parsed, log_data, accept ]
      end

      return { success: false, error: "Failed to extract feedback data from email" } unless result[:success]

      Rails.logger.info("[RoundFeedbackProcessor] Successfully extracted with #{result[:provider]} (confidence: #{result[:parsed]&.dig(:confidence_score)}, result: #{result[:parsed]&.dig(:result)})")
      {
        success: true,
        data: result[:parsed],
        provider: result[:provider],
        llm_api_log_id: result[:llm_api_log_id],
        latency_ms: result[:latency_ms]
      }
    end

    # Extracts field names that were populated
    #
    # @param parsed [Hash]
    # @return [Array<String>]
    def extract_field_names(parsed)
      fields = []
      round_context = parsed[:round_context] || {}
      feedback = parsed[:feedback] || {}
      next_steps = parsed[:next_steps] || {}

      fields << "result" if parsed[:result].present?
      fields << "sentiment" if parsed[:sentiment].present?
      fields << "stage_mentioned" if round_context[:stage_mentioned].present?
      fields << "interviewer_mentioned" if round_context[:interviewer_mentioned].present?
      fields << "feedback_summary" if feedback[:summary].present?
      fields << "strengths" if feedback[:strengths].present?
      fields << "improvements" if feedback[:improvements].present?
      fields << "next_round_hint" if next_steps[:next_round_hint].present?

      fields
    end

    # Builds the extraction prompt
    #
    # @return [String]
    def build_prompt
      subject = synced_email.subject || "(No subject)"
      body = extract_body_content
      from_email = synced_email.from_email || ""
      from_name = synced_email.from_name || ""
      company_name = application.company&.name || synced_email.signal_company_name || ""
      recent_rounds = build_recent_rounds_context
      vars = {
        subject: subject,
        body: body.truncate(5000),
        from_email: from_email,
        from_name: from_name,
        company_name: company_name,
        recent_rounds: recent_rounds
      }

      Ai::PromptBuilderService.new(
        prompt_class: Ai::RoundFeedbackExtractionPrompt,
        variables: vars
      ).run
    end

    # Builds context about recent interview rounds
    #
    # @return [String] JSON array of recent rounds
    def build_recent_rounds_context
      rounds = application.interview_rounds.order(scheduled_at: :desc).limit(5)

      rounds_data = rounds.map do |round|
        {
          id: round.id,
          stage: round.stage,
          stage_name: round.stage_name,
          scheduled_at: round.scheduled_at&.iso8601,
          interviewer_name: round.interviewer_name,
          result: round.result
        }
      end

      JSON.pretty_generate(rounds_data)
    end

    # Extracts body content from email
    #
    # @return [String]
    def extract_body_content
      if synced_email.body_preview.present?
        synced_email.body_preview
      elsif synced_email.body_html.present?
        ActionController::Base.helpers.strip_tags(synced_email.body_html)
      else
        synced_email.snippet || ""
      end
    end

    # Parses LLM response JSON
    #
    # @param content [String] Raw LLM response
    # @return [Hash, nil]
    def parse_response(content)
      parsed = Ai::ResponseParserService.new(content).parse(symbolize: true)
      return parsed if parsed

      Rails.logger.warn("[RoundFeedbackProcessor] Failed to parse JSON")
      nil
    end

    # Finds the matching interview round for this feedback
    #
    # @param data [Hash] Extracted feedback data
    # @return [InterviewRound, nil]
    def find_matching_round(data)
      round_context = data[:round_context] || {}

      # Strategy 1: Match by interviewer name
      if round_context[:interviewer_mentioned].present?
        round = application.interview_rounds
          .where("interviewer_name ILIKE ?", "%#{round_context[:interviewer_mentioned]}%")
          .where(result: :pending)
          .order(scheduled_at: :desc)
          .first
        if round
          Rails.logger.info("[RoundFeedbackProcessor] Matched round ##{round.id} by interviewer name")
          return round
        end
      end

      # Strategy 2: Match by stage/type mentioned
      if round_context[:stage_mentioned].present?
        stage = infer_stage_from_text(round_context[:stage_mentioned])
        if stage
          round = application.interview_rounds
            .where(stage: stage, result: :pending)
            .order(scheduled_at: :desc)
            .first
          if round
            Rails.logger.info("[RoundFeedbackProcessor] Matched round ##{round.id} by stage")
            return round
          end
        end
      end

      # Strategy 3: Most recent pending round
      round = application.interview_rounds
        .where(result: :pending)
        .order(scheduled_at: :desc)
        .first

      Rails.logger.info("[RoundFeedbackProcessor] Matched round ##{round&.id || 'none'} by most recent pending")
      round
    end

    # Infers stage enum from text description
    #
    # @param text [String]
    # @return [Symbol, nil]
    def infer_stage_from_text(text)
      text_lower = text.downcase

      return :screening if text_lower.match?(/screen|phone|initial|intro/)
      return :technical if text_lower.match?(/technical|coding|system design|live coding/)
      return :hiring_manager if text_lower.match?(/hiring manager|manager|lead/)
      return :culture_fit if text_lower.match?(/culture|behavioral|values|team fit/)

      nil
    end

    # Updates existing round with feedback
    #
    # @param round [InterviewRound]
    # @param data [Hash]
    def update_round_with_feedback(round, data)
      # Update round result
      result = map_result(data[:result])
      round.update!(
        result: result,
        completed_at: Time.current,
        source_email_id: synced_email.id
      )

      # Create interview feedback if detailed feedback exists
      if data.dig(:feedback, :has_detailed_feedback)
        create_interview_feedback(round, data)
      end
    end

    # Creates a new round with the feedback result
    # Used when we receive feedback but don't have a matching round
    #
    # @param data [Hash]
    # @return [InterviewRound, nil]
    def create_round_from_feedback(data)
      existing = attach_feedback_to_latest_round(data)
      return existing if existing

      round_context = data[:round_context] || {}
      stage = infer_stage_from_text(round_context[:stage_mentioned] || "") || :other
      result = map_result(data[:result])

      position = application.interview_rounds.maximum(:position).to_i + 1

      round = application.interview_rounds.create!(
        stage: stage,
        stage_name: round_context[:stage_mentioned],
        result: result,
        completed_at: Time.current,
        source_email_id: synced_email.id,
        interviewer_name: round_context[:interviewer_mentioned],
        position: position,
        notes: "📬 Created from feedback email"
      )

      create_interview_feedback(round, data) if data.dig(:feedback, :has_detailed_feedback)

      round
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[RoundFeedbackProcessor] Failed to create round: #{e.message}")
      nil
    end

    # Attaches feedback to latest round when app is already rejected
    #
    # @param data [Hash]
    # @return [InterviewRound, nil]
    def attach_feedback_to_latest_round(data)
      return nil unless application&.rejected?
      return nil unless data.dig(:feedback, :has_detailed_feedback)

      round_context = data[:round_context] || {}
      has_matching_signal = round_context[:stage_mentioned].present? ||
        round_context[:interviewer_mentioned].present? ||
        round_context[:date_mentioned].present?
      return nil if has_matching_signal

      round = application.latest_round
      return nil unless round
      return round if round.interview_feedback.present?

      create_interview_feedback(round, data)
      round
    end

    # Creates interview feedback record
    #
    # @param round [InterviewRound]
    # @param data [Hash]
    def create_interview_feedback(round, data)
      feedback_data = data[:feedback] || {}

      # Don't create duplicate feedback
      return if round.interview_feedback.present?

      feedback = InterviewFeedback.create!(
        interview_round: round,
        went_well: Array(feedback_data[:strengths]).join("\n• "),
        to_improve: Array(feedback_data[:improvements]).join("\n• "),
        ai_summary: feedback_data[:summary],
        interviewer_notes: feedback_data[:full_feedback_text],
        recommended_action: determine_recommended_action(data)
      )

      Rails.logger.info("[RoundFeedbackProcessor] Created InterviewFeedback ##{feedback.id} for round ##{round.id}")
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[RoundFeedbackProcessor] Failed to create feedback: #{e.message}")
    end

    # Determines recommended action based on feedback
    #
    # @param data [Hash]
    # @return [String, nil]
    def determine_recommended_action(data)
      case data[:result]
      when "passed"
        next_steps = data[:next_steps] || {}
        if next_steps[:has_next_round]
          "Prepare for #{next_steps[:next_round_type] || 'next round'}"
        else
          "Follow up on next steps"
        end
      when "failed"
        "Review feedback and apply learnings to future interviews"
      when "waitlisted"
        "Follow up in 1-2 weeks if no update"
      else
        nil
      end
    end

    # Maps result string to InterviewRound result enum
    #
    # @param result_str [String]
    # @return [Symbol]
    def map_result(result_str)
      case result_str&.downcase
      when "passed" then :passed
      when "failed" then :failed
      when "waitlisted" then :waitlisted
      else :pending
      end
    end

    # Returns provider chain for LLM
    #
    # @return [Array<String>]
    def provider_chain
      LlmProviders::ProviderConfigHelper.all_providers
    end

    # Gets provider instance
    #
    # @param provider_name [String]
    # @return [Object, nil]
    def get_provider_instance(provider_name)
      case provider_name.to_s.downcase
      when "openai" then LlmProviders::OpenaiProvider.new
      when "anthropic" then LlmProviders::AnthropicProvider.new
      when "ollama" then LlmProviders::OllamaProvider.new
      else nil
      end
    end
  end
end
