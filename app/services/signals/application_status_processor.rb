# frozen_string_literal: true

module Signals
  # Service for processing application status change emails (rejection, offer)
  #
  # Processes emails classified as rejection or offer to update application status
  # and create company feedback records.
  #
  # @example
  #   processor = Signals::ApplicationStatusProcessor.new(synced_email)
  #   result = processor.process
  #   if result[:success]
  #     # Application status updated
  #   end
  #
  class ApplicationStatusProcessor
    attr_reader :synced_email, :application

    # Email types that this processor handles
    PROCESSABLE_TYPES = %w[rejection offer].freeze

    # Minimum confidence score to accept extraction results
    MIN_CONFIDENCE_SCORE = 0.6

    # Operation type for logging
    OPERATION_TYPE = :application_status_extraction

    # Initialize the processor
    #
    # @param synced_email [SyncedEmail] The email to process
    def initialize(synced_email)
      @synced_email = synced_email
      @application = synced_email.interview_application
    end

    # Processes the email to update application status
    #
    # @return [Hash] Result with success status
    def process
      Rails.logger.info("[ApplicationStatusProcessor] Processing email ##{synced_email.id}: #{synced_email.subject}")

      return skip_result("Email not matched to application") unless application
      return skip_result("Email type not processable") unless processable?
      return skip_result("No email content") unless content_available?

      # Extract status data using LLM
      extraction = extract_status_data
      unless extraction[:success]
        Rails.logger.warn("[ApplicationStatusProcessor] Extraction failed for email ##{synced_email.id}: #{extraction[:error]}")
        return { success: false, error: extraction[:error] }
      end

      data = extraction[:data]
      status_change = data[:status_change] || {}

      result = case status_change[:type]
      when "rejection"
        handle_rejection(data)
      when "offer"
        handle_offer(data)
      when "withdrawal", "ghosted", "on_hold"
        handle_other_status(data)
      else
        skip_result("No status change detected")
      end

      result[:llm_api_log_id] = extraction[:llm_api_log_id] if extraction[:llm_api_log_id]
      result
    rescue StandardError => e
      notify_error(e)
      Rails.logger.error("[ApplicationStatusProcessor] Error processing email ##{synced_email&.id}: #{e.message}")
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
      Rails.logger.info("[ApplicationStatusProcessor] Skipped email ##{synced_email&.id}: #{reason}")
      { success: false, skipped: true, reason: reason }
    end

    # Extracts status data using LLM with observability
    #
    # @return [Hash] Result with success and data
    def extract_status_data
      prompt = build_prompt
      prompt_template = Ai::StatusExtractionPrompt.active_prompt
      system_message = prompt_template&.system_prompt.presence || Ai::StatusExtractionPrompt.default_system_prompt

      provider_chain.each do |provider_name|
        provider = get_provider_instance(provider_name)
        next unless provider&.available?

        Rails.logger.info("[ApplicationStatusProcessor] Trying provider: #{provider_name}")
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          result = provider.run(prompt, max_tokens: 1500, temperature: 0.1, system_message: system_message)
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

          # Log the API call
          parsed = result[:error] ? nil : parse_response(result[:content])
          log = log_extraction_result(provider_name, result[:model], result, parsed, latency_ms, prompt)

          if result[:error]
            Rails.logger.warn("[ApplicationStatusProcessor] Provider #{provider_name} error: #{result[:error]}")
            next
          end

          if result[:rate_limit]
            Rails.logger.warn("[ApplicationStatusProcessor] Provider #{provider_name} rate limited")
            next
          end

          if parsed && (parsed[:confidence_score].nil? || parsed[:confidence_score] >= MIN_CONFIDENCE_SCORE)
            status_type = parsed.dig(:status_change, :type)
            Rails.logger.info("[ApplicationStatusProcessor] Successfully extracted with #{provider_name} (confidence: #{parsed[:confidence_score]}, type: #{status_type})")
            return {
              success: true,
              data: parsed,
              provider: provider_name,
              llm_api_log_id: log&.id,
              latency_ms: latency_ms
            }
          else
            Rails.logger.warn("[ApplicationStatusProcessor] Low confidence (#{parsed&.dig(:confidence_score)}) from #{provider_name}")
          end
        rescue StandardError => e
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
          Rails.logger.warn("[ApplicationStatusProcessor] Provider #{provider_name} failed (#{latency_ms}ms): #{e.message}")
          notify_provider_error(e, provider_name, latency_ms)
          next
        end
      end

      { success: false, error: "Failed to extract status data from email" }
    end

    # Logs the extraction result to Ai::LlmApiLog
    #
    # @param provider_name [String] Provider name
    # @param model [String] Model identifier
    # @param result [Hash] Raw LLM result
    # @param parsed [Hash, nil] Parsed response data
    # @param latency_ms [Integer] Latency in milliseconds
    # @param prompt [String] The prompt used
    # @return [Ai::LlmApiLog, nil]
    def log_extraction_result(provider_name, model, result, parsed, latency_ms, prompt)
      prompt_template = Ai::StatusExtractionPrompt.active_prompt

      logger = Ai::ApiLoggerService.new(
        operation_type: OPERATION_TYPE,
        loggable: synced_email,
        provider: provider_name,
        model: model || "unknown",
        llm_prompt: prompt_template
      )

      log_data = {
        confidence: parsed&.dig(:confidence_score),
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens],
        error: result[:error],
        rate_limit: result[:rate_limit],
        provider_request: result[:provider_request],
        provider_response: result[:provider_response],
        provider_error_response: result[:provider_error_response],
        http_status: result[:http_status],
        response_headers: result[:response_headers],
        provider_endpoint: result[:provider_endpoint]
      }

      # Add parsed fields for successful extractions
      if parsed.present?
        status_change = parsed[:status_change] || {}
        rejection = parsed[:rejection_details] || {}
        offer = parsed[:offer_details] || {}
        feedback = parsed[:feedback] || {}

        log_data.merge!(
          status_type: status_change[:type],
          is_final: status_change[:is_final],
          sentiment: parsed[:sentiment],
          has_feedback: feedback[:has_feedback],
          rejection_reason: rejection[:reason].present?,
          offer_role: offer[:role_title],
          extracted_fields: extract_field_names(parsed)
        )
      end

      logger.record_result(
        log_data,
        latency_ms: latency_ms,
        prompt: prompt,
        content_size: extract_body_content.bytesize
      )
    rescue StandardError => e
      Rails.logger.warn("[ApplicationStatusProcessor] Failed to log extraction result: #{e.message}")
      nil
    end

    # Extracts field names that were populated
    #
    # @param parsed [Hash]
    # @return [Array<String>]
    def extract_field_names(parsed)
      fields = []
      status_change = parsed[:status_change] || {}
      rejection = parsed[:rejection_details] || {}
      offer = parsed[:offer_details] || {}
      feedback = parsed[:feedback] || {}

      fields << "status_type" if status_change[:type].present?
      fields << "is_final" unless status_change[:is_final].nil?
      fields << "sentiment" if parsed[:sentiment].present?
      fields << "rejection_reason" if rejection[:reason].present?
      fields << "stage_rejected_at" if rejection[:stage_rejected_at].present?
      fields << "offer_role" if offer[:role_title].present?
      fields << "offer_start_date" if offer[:start_date].present?
      fields << "response_deadline" if offer[:response_deadline].present?
      fields << "feedback_text" if feedback[:feedback_text].present?

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
      current_status = application.pipeline_stage.to_s

      prompt_template = Ai::StatusExtractionPrompt.active_prompt
      if prompt_template
        prompt_template.build_prompt(
          subject: subject,
          body: body.truncate(5000),
          from_email: from_email,
          from_name: from_name,
          company_name: company_name,
          current_status: current_status
        )
      else
        Ai::StatusExtractionPrompt.default_prompt_template
          .gsub("{{subject}}", subject)
          .gsub("{{body}}", body.truncate(5000))
          .gsub("{{from_email}}", from_email)
          .gsub("{{from_name}}", from_name)
          .gsub("{{company_name}}", company_name)
          .gsub("{{current_status}}", current_status)
      end
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
      return nil if content.blank?

      cleaned = content.gsub(/```json\n?/, "").gsub(/```\n?/, "").strip
      JSON.parse(cleaned, symbolize_names: true)
    rescue JSON::ParserError => e
      Rails.logger.warn("[ApplicationStatusProcessor] Failed to parse JSON: #{e.message}")
      nil
    end

    # Handles rejection emails
    #
    # @param data [Hash] Extracted data
    # @return [Hash]
    def handle_rejection(data)
      Rails.logger.info("[ApplicationStatusProcessor] Handling rejection for application ##{application.id}")

      # Only update if application is still active
      if application.active?
        begin
          application.reject!
          application.move_to_closed! if application.may_move_to_closed?
          Rails.logger.info("[ApplicationStatusProcessor] Updated application ##{application.id} to rejected/closed")
        rescue AASM::InvalidTransition => e
          Rails.logger.warn("[ApplicationStatusProcessor] Could not transition to rejected: #{e.message}")
        end
      end

      # Create company feedback
      create_rejection_feedback(data)

      { success: true, action: :rejection, application: application }
    end

    # Handles offer emails
    #
    # @param data [Hash] Extracted data
    # @return [Hash]
    def handle_offer(data)
      Rails.logger.info("[ApplicationStatusProcessor] Handling offer for application ##{application.id}")

      # Move to offer stage
      if application.may_move_to_offer?
        application.move_to_offer!
        Rails.logger.info("[ApplicationStatusProcessor] Moved application ##{application.id} to offer stage")
      end

      # Create company feedback with offer details
      create_offer_feedback(data)

      { success: true, action: :offer, application: application }
    end

    # Handles other status changes (withdrawal, ghosted, on_hold)
    #
    # @param data [Hash] Extracted data
    # @return [Hash]
    def handle_other_status(data)
      status_change = data[:status_change] || {}
      status_type = status_change[:type]

      Rails.logger.info("[ApplicationStatusProcessor] Handling #{status_type} for application ##{application.id}")

      case status_type
      when "withdrawal"
        # Company withdrew the position
        if application.active?
          application.archive! if application.may_archive?
          Rails.logger.info("[ApplicationStatusProcessor] Archived application ##{application.id} (withdrawal)")
        end
        create_generic_feedback(data, "Position withdrawn")
      when "ghosted"
        # Mark as potentially dead
        create_generic_feedback(data, "No response - possible ghost")
      when "on_hold"
        # Create feedback noting the hold
        create_generic_feedback(data, "Position/process on hold")
      end

      { success: true, action: status_type.to_sym, application: application }
    end

    # Creates rejection feedback record
    #
    # @param data [Hash] Extracted data
    def create_rejection_feedback(data)
      rejection = data[:rejection_details] || {}
      feedback = data[:feedback] || {}

      # Don't create duplicate feedback
      return if application.company_feedback.present?

      fb = CompanyFeedback.create!(
        interview_application: application,
        source_email_id: synced_email.id,
        feedback_type: "rejection",
        feedback_text: feedback[:feedback_text],
        rejection_reason: build_rejection_reason(rejection),
        received_at: synced_email.email_date || Time.current,
        self_reflection: nil, # User can add later
        next_steps: rejection[:door_open] ? "Keep in touch for future opportunities" : nil
      )

      Rails.logger.info("[ApplicationStatusProcessor] Created rejection CompanyFeedback ##{fb.id}")
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[ApplicationStatusProcessor] Failed to create rejection feedback: #{e.message}")
    end

    # Builds rejection reason text
    #
    # @param rejection [Hash]
    # @return [String]
    def build_rejection_reason(rejection)
      parts = []
      parts << rejection[:reason] if rejection[:reason].present?
      parts << "Rejected at: #{rejection[:stage_rejected_at]} stage" if rejection[:stage_rejected_at].present?
      parts << "(Generic rejection email)" if rejection[:is_generic]

      parts.join("\n")
    end

    # Creates offer feedback record
    #
    # @param data [Hash] Extracted data
    def create_offer_feedback(data)
      offer = data[:offer_details] || {}
      feedback = data[:feedback] || {}

      # Don't create duplicate feedback
      return if application.company_feedback.present?

      next_steps = []
      next_steps << offer[:next_steps] if offer[:next_steps].present?
      next_steps << "Respond by: #{offer[:response_deadline]}" if offer[:response_deadline].present?
      next_steps << "Start date: #{offer[:start_date]}" if offer[:start_date].present?

      fb = CompanyFeedback.create!(
        interview_application: application,
        source_email_id: synced_email.id,
        feedback_type: "offer",
        feedback_text: build_offer_text(offer, feedback),
        rejection_reason: nil,
        received_at: synced_email.email_date || Time.current,
        self_reflection: nil,
        next_steps: next_steps.join("\n")
      )

      Rails.logger.info("[ApplicationStatusProcessor] Created offer CompanyFeedback ##{fb.id}")
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[ApplicationStatusProcessor] Failed to create offer feedback: #{e.message}")
    end

    # Builds offer text
    #
    # @param offer [Hash]
    # @param feedback [Hash]
    # @return [String]
    def build_offer_text(offer, feedback)
      parts = []
      parts << "🎉 Offer received!"
      parts << "Role: #{offer[:role_title]}" if offer[:role_title].present?
      parts << "Department: #{offer[:department]}" if offer[:department].present?
      parts << feedback[:feedback_text] if feedback[:feedback_text].present?

      parts.join("\n")
    end

    # Creates generic feedback record
    #
    # @param data [Hash]
    # @param summary [String]
    def create_generic_feedback(data, summary)
      feedback = data[:feedback] || {}

      # Don't create duplicate feedback
      return if application.company_feedback.present?

      fb = CompanyFeedback.create!(
        interview_application: application,
        source_email_id: synced_email.id,
        feedback_type: "general",
        feedback_text: "#{summary}\n\n#{feedback[:feedback_text]}".strip,
        received_at: synced_email.email_date || Time.current
      )

      Rails.logger.info("[ApplicationStatusProcessor] Created generic CompanyFeedback ##{fb.id}")
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[ApplicationStatusProcessor] Failed to create feedback: #{e.message}")
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

    # Notifies of processing errors
    #
    # @param exception [Exception]
    def notify_error(exception)
      ExceptionNotifier.notify(exception, {
        context: "application_status_processor",
        severity: "error",
        synced_email_id: synced_email&.id,
        application_id: application&.id,
        email_type: synced_email&.email_type,
        company: application&.company&.name,
        user: { id: synced_email&.user_id, email: synced_email&.user&.email_address }
      })
    end

    # Notifies of AI provider errors with rich context
    #
    # @param exception [Exception]
    # @param provider_name [String]
    # @param latency_ms [Integer, nil] Processing time if available
    def notify_provider_error(exception, provider_name, latency_ms = nil)
      ExceptionNotifier.notify_ai_error(exception, {
        operation: "application_status_extraction",
        severity: "warning",
        provider_name: provider_name,
        analyzable_type: "SyncedEmail",
        analyzable_id: synced_email&.id,
        processing_time_ms: latency_ms
      })
    end
  end
end
