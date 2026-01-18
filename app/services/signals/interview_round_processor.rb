# frozen_string_literal: true

module Signals
  # Service for automatically creating interview rounds from scheduling confirmation emails
  #
  # Processes emails classified as scheduling, interview_invite, or interview_reminder
  # to extract interview details and create InterviewRound records.
  #
  # @example
  #   processor = Signals::InterviewRoundProcessor.new(synced_email)
  #   result = processor.process
  #   if result[:success]
  #     # Interview round created or updated
  #   end
  #
  class InterviewRoundProcessor < ApplicationService
    attr_reader :synced_email, :application

    # Email types that this processor handles
    PROCESSABLE_TYPES = %w[scheduling interview_invite interview_reminder].freeze

    # Minimum confidence score to accept extraction results
    MIN_CONFIDENCE_SCORE = 0.5

    # Operation type for logging
    OPERATION_TYPE = :interview_round_extraction

    # Initialize the processor
    #
    # @param synced_email [SyncedEmail] The email to process
    def initialize(synced_email)
      @synced_email = synced_email
      @application = synced_email.interview_application
    end

    # Processes the email to create/update interview round
    #
    # @return [Hash] Result with success status and round
    def process
      Rails.logger.info("[InterviewRoundProcessor] Processing email ##{synced_email.id}: #{synced_email.subject}")

      return skip_result("Email not matched to application") unless application
      return skip_result("Email type not processable") unless processable?
      return skip_result("No email content") unless content_available?

      # Check if we already processed this email
      existing_round = InterviewRound.find_by(source_email_id: synced_email.id)
      if existing_round
        Rails.logger.info("[InterviewRoundProcessor] Email ##{synced_email.id} already processed -> Round ##{existing_round.id}")
        return skip_result("Already processed", round: existing_round)
      end

      # Extract interview details using LLM
      extraction = extract_interview_data
      unless extraction[:success]
        Rails.logger.warn("[InterviewRoundProcessor] Extraction failed for email ##{synced_email.id}: #{extraction[:error]}")
        return { success: false, error: extraction[:error] }
      end

      # Create or update interview round
      round = create_or_update_round(extraction[:data])

      if round.persisted?
        Rails.logger.info("[InterviewRoundProcessor] Created round ##{round.id} for email ##{synced_email.id}")
        { success: true, round: round, action: :created, llm_api_log_id: extraction[:llm_api_log_id] }
      else
        Rails.logger.error("[InterviewRoundProcessor] Failed to persist round: #{round.errors.full_messages.join(', ')}")
        { success: false, error: round.errors.full_messages.join(", ") }
      end
    rescue StandardError => e
      notify_error(
        e,
        context: "interview_round_processor",
        user: synced_email&.user,
        synced_email_id: synced_email&.id,
        application_id: application&.id,
        email_type: synced_email&.email_type,
        company: application&.company&.name
      )
      Rails.logger.error("[InterviewRoundProcessor] Error processing email ##{synced_email&.id}: #{e.message}")
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
    # @param data [Hash] Additional data
    # @return [Hash]
    def skip_result(reason, data = {})
      Rails.logger.info("[InterviewRoundProcessor] Skipped email ##{synced_email&.id}: #{reason}")
      { success: false, skipped: true, reason: reason }.merge(data)
    end

    # Extracts interview data using LLM with observability
    #
    # @return [Hash] Result with success and data
    def extract_interview_data
      prompt = build_prompt
      prompt_template = Ai::InterviewExtractionPrompt.active_prompt
      system_message = prompt_template&.system_prompt.presence || Ai::InterviewExtractionPrompt.default_system_prompt

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
        interview = parsed[:interview] || {}
        interviewer = parsed[:interviewer] || {}
        logistics = parsed[:logistics] || {}

        log_data = {
          confidence: parsed&.dig(:confidence_score),
          scheduled_at: interview[:scheduled_at],
          duration_minutes: interview[:duration_minutes],
          stage: interview[:stage],
          interviewer_name: interviewer[:name],
          video_link: logistics[:video_link].present?,
          confirmation_source: parsed[:confirmation_source],
          extracted_fields: extract_field_names(parsed)
        }.compact

        confidence_score = parsed[:confidence_score]
        if confidence_score && confidence_score < MIN_CONFIDENCE_SCORE
          Rails.logger.warn("[InterviewRoundProcessor] Low confidence (#{confidence_score}) from provider")
        end
        accept = confidence_score.nil? || confidence_score >= MIN_CONFIDENCE_SCORE
        [ parsed, log_data, accept ]
      end

      return { success: false, error: "Failed to extract interview data from email" } unless result[:success]

      Rails.logger.info("[InterviewRoundProcessor] Successfully extracted with #{result[:provider]} (confidence: #{result[:parsed]&.dig(:confidence_score)})")
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
      interview = parsed[:interview] || {}
      interviewer = parsed[:interviewer] || {}
      logistics = parsed[:logistics] || {}

      fields << "scheduled_at" if interview[:scheduled_at].present?
      fields << "duration_minutes" if interview[:duration_minutes].present?
      fields << "stage" if interview[:stage].present?
      fields << "interviewer_name" if interviewer[:name].present?
      fields << "interviewer_role" if interviewer[:role].present?
      fields << "video_link" if logistics[:video_link].present?
      fields << "confirmation_source" if parsed[:confirmation_source].present?

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
      vars = {
        subject: subject,
        body: body.truncate(5000),
        from_email: from_email,
        from_name: from_name,
        company_name: company_name
      }

      Ai::PromptBuilderService.new(
        prompt_class: Ai::InterviewExtractionPrompt,
        variables: vars
      ).run
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

      Rails.logger.warn("[InterviewRoundProcessor] Failed to parse JSON")
      nil
    end

    # Creates or updates interview round from extracted data
    #
    # @param data [Hash] Extracted interview data
    # @return [InterviewRound]
    def create_or_update_round(data)
      interview_data = data[:interview] || {}

      # Parse scheduled time
      scheduled_at = parse_scheduled_time(interview_data[:scheduled_at])

      # Determine stage
      stage = map_stage(interview_data[:stage])

      # Find existing round by scheduled time (within 1 hour window)
      existing = find_existing_round(scheduled_at) if scheduled_at

      if existing
        update_existing_round(existing, data)
      else
        create_new_round(data, scheduled_at, stage)
      end
    end

    # Finds existing round by scheduled time
    #
    # @param scheduled_at [DateTime]
    # @return [InterviewRound, nil]
    def find_existing_round(scheduled_at)
      return nil unless scheduled_at

      application.interview_rounds
        .where(scheduled_at: (scheduled_at - 1.hour)..(scheduled_at + 1.hour))
        .first
    end

    # Updates existing interview round
    #
    # @param round [InterviewRound]
    # @param data [Hash]
    # @return [InterviewRound]
    def update_existing_round(round, data)
      interview_data = data[:interview] || {}
      interviewer_data = data[:interviewer] || {}
      logistics_data = data[:logistics] || {}

      updates = {}
      updates[:video_link] = logistics_data[:video_link] if logistics_data[:video_link].present?
      updates[:source_email_id] = synced_email.id
      updates[:confirmation_source] = data[:confirmation_source] if data[:confirmation_source].present?
      updates[:interviewer_name] = interviewer_data[:name] if interviewer_data[:name].present? && round.interviewer_name.blank?
      updates[:interviewer_role] = interviewer_data[:role] if interviewer_data[:role].present? && round.interviewer_role.blank?
      updates[:duration_minutes] = interview_data[:duration_minutes] if interview_data[:duration_minutes].present? && round.duration_minutes.blank?

      if updates.any?
        round.update!(updates)
        Rails.logger.info("[InterviewRoundProcessor] Updated existing round ##{round.id}")
      end
      round
    end

    # Creates new interview round
    #
    # @param data [Hash]
    # @param scheduled_at [DateTime]
    # @param stage [Symbol]
    # @return [InterviewRound]
    def create_new_round(data, scheduled_at, stage)
      interview_data = data[:interview] || {}
      interviewer_data = data[:interviewer] || {}
      logistics_data = data[:logistics] || {}

      # Calculate position
      position = application.interview_rounds.maximum(:position).to_i + 1

      application.interview_rounds.create!(
        stage: stage,
        stage_name: interview_data[:stage_name],
        scheduled_at: scheduled_at,
        duration_minutes: interview_data[:duration_minutes] || 30,
        interviewer_name: interviewer_data[:name],
        interviewer_role: interviewer_data[:role],
        video_link: logistics_data[:video_link],
        source_email_id: synced_email.id,
        confirmation_source: data[:confirmation_source],
        position: position,
        result: :pending,
        notes: build_round_notes(data)
      )
    end

    # Builds notes for the interview round
    #
    # @param data [Hash]
    # @return [String, nil]
    def build_round_notes(data)
      notes = []
      logistics = data[:logistics] || {}

      notes << "📬 Created from email signal" if synced_email.present?
      notes << "📍 Location: #{logistics[:location]}" if logistics[:location].present?
      notes << "📞 Phone: #{logistics[:phone_number]}" if logistics[:phone_number].present?
      notes << "🔑 Meeting ID: #{logistics[:meeting_id]}" if logistics[:meeting_id].present?
      notes << "🔐 Passcode: #{logistics[:passcode]}" if logistics[:passcode].present?
      notes << "📝 #{data[:additional_instructions]}" if data[:additional_instructions].present?

      notes.any? ? notes.join("\n") : nil
    end

    # Parses scheduled time from various formats
    #
    # @param time_str [String]
    # @return [DateTime, nil]
    def parse_scheduled_time(time_str)
      return nil if time_str.blank?

      DateTime.parse(time_str)
    rescue ArgumentError, TypeError => e
      Rails.logger.warn("[InterviewRoundProcessor] Failed to parse time '#{time_str}': #{e.message}")
      nil
    end

    # Maps extracted stage to InterviewRound stage enum
    #
    # @param stage_str [String]
    # @return [Symbol]
    def map_stage(stage_str)
      case stage_str&.downcase
      when "screening" then :screening
      when "technical" then :technical
      when "hiring_manager" then :hiring_manager
      when "culture_fit" then :culture_fit
      else :other
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
