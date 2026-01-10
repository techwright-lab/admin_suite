# frozen_string_literal: true

module Opportunities
  # Service for AI-powered extraction of job opportunity details from recruiter emails
  #
  # Uses configured LLM providers to extract structured data like company name,
  # job role, links, and key details from unstructured email content.
  # Logs all LLM calls to Ai::LlmApiLog for observability.
  #
  # @example
  #   service = Opportunities::ExtractionService.new(opportunity)
  #   result = service.extract
  #   if result[:success]
  #     # Update opportunity with extracted data
  #   end
  #
  class ExtractionService
    attr_reader :opportunity

    # Initialize the service
    #
    # @param opportunity [Opportunity] The opportunity to extract data for
    def initialize(opportunity)
      @opportunity = opportunity
    end

    # Extracts job opportunity data using AI
    #
    # @return [Hash] Result with success status and extracted data
    def extract
      return { success: false, error: "No email content available" } unless email_content_available?

      # Build prompt with email content
      prompt = build_prompt

      # Try extraction with LLM providers
      result = extract_with_llm(prompt)

      if result[:success]
        # Update the opportunity with extracted data
        update_opportunity(result[:data])
        result
      else
        { success: false, error: result[:error] || "Extraction failed" }
      end
    rescue StandardError => e
      notify_extraction_error(e)
      { success: false, error: e.message }
    end

    private

    # Checks if email content is available
    #
    # @return [Boolean]
    def email_content_available?
      synced_email.present? && (
        synced_email.body_preview.present? ||
        synced_email.snippet.present? ||
        synced_email.subject.present?
      )
    end

    # Returns the associated synced email
    #
    # @return [SyncedEmail, nil]
    def synced_email
      @synced_email ||= opportunity.synced_email
    end

    # Builds the extraction prompt
    #
    # @return [String]
    def build_prompt
      subject = synced_email.subject || "(No subject)"
      body = synced_email.body_preview || synced_email.snippet || ""

      prompt_template = Ai::EmailExtractionPrompt.active_prompt

      if prompt_template
        prompt_template.build_prompt(subject: subject, body: body.truncate(4000))
      else
        Ai::EmailExtractionPrompt.default_prompt_template
          .gsub("{{subject}}", subject)
          .gsub("{{body}}", body.truncate(4000))
      end
    end

    # Extracts data using LLM providers
    #
    # @param prompt [String] The extraction prompt
    # @return [Hash] Result with success and data
    def extract_with_llm(prompt)
      prompt_template = Ai::EmailExtractionPrompt.active_prompt
      system_message = prompt_template&.system_prompt.presence || Ai::EmailExtractionPrompt.default_system_prompt

      provider_chain.each do |provider_name|
        provider = get_provider_instance(provider_name)
        next unless provider&.available?

        begin
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = provider.run(prompt, max_tokens: 2000, temperature: 0.1, system_message: system_message)
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

          if result[:error]
            Rails.logger.warn("Provider #{provider_name} returned error: #{result[:error]}")
            log_extraction_result(provider_name, result[:model], result, nil, latency_ms, prompt)
            next
          end

          parsed = parse_response(result[:content])

          # Log the extraction result
          log_extraction_result(
            provider_name,
            result[:model],
            result,
            parsed,
            latency_ms,
            prompt
          )

          if parsed[:confidence_score] && parsed[:confidence_score] >= 0.5
            return { success: true, data: parsed, provider: provider_name }
          end
        rescue StandardError => e
          Rails.logger.warn("Provider #{provider_name} failed: #{e.message}")
          notify_extraction_error(e, provider_name)
          next
        end
      end

      { success: false, error: "All providers failed or returned low confidence" }
    end

    # Logs the extraction result to Ai::LlmApiLog
    #
    # @param provider_name [String] Provider name
    # @param model [String] Model identifier
    # @param result [Hash] Raw LLM result
    # @param parsed [Hash, nil] Parsed response data
    # @param latency_ms [Integer] Latency in milliseconds
    # @param prompt [String] The prompt used
    def log_extraction_result(provider_name, model, result, parsed, latency_ms, prompt)
      prompt_template = Ai::EmailExtractionPrompt.active_prompt

      logger = Ai::ApiLoggerService.new(
        operation_type: :email_extraction,
        loggable: opportunity,
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
        log_data.merge!(
          company_name: parsed[:company_name],
          job_role_title: parsed[:job_role_title],
          job_url: parsed[:job_url]
        )
      end

      logger.record_result(
        log_data,
        latency_ms: latency_ms,
        prompt: prompt,
        content_size: (synced_email.body_preview || synced_email.snippet || "").bytesize
      )
    rescue => e
      Rails.logger.warn("Failed to log email extraction result: #{e.message}")
    end

    # Returns the provider chain
    #
    # @return [Array<String>]
    def provider_chain
      LlmProviders::ProviderConfigHelper.all_providers
    end

    # Gets a provider instance
    #
    # @param provider_name [String]
    # @return [LlmProviders::BaseProvider, nil]
    def get_provider_instance(provider_name)
      case provider_name.to_s.downcase
      when "openai"
        LlmProviders::OpenaiProvider.new
      when "anthropic"
        LlmProviders::AnthropicProvider.new
      when "ollama"
        LlmProviders::OllamaProvider.new
      else
        nil
      end
    end

    # Parses the LLM response
    #
    # @param response_text [String]
    # @return [Hash]
    def parse_response(response_text)
      return { confidence_score: 0.0 } unless response_text.present?

      # Try to extract JSON from the response
      json_match = response_text.match(/\{.*\}/m)
      return { confidence_score: 0.0 } unless json_match

      data = JSON.parse(json_match[0])
      data.deep_symbolize_keys
    rescue JSON::ParserError
      { confidence_score: 0.0 }
    end

    # Updates the opportunity with extracted data
    #
    # @param data [Hash] Extracted data
    # @return [void]
    def update_opportunity(data)
      updates = {}

      # Basic job info
      updates[:company_name] = data[:company_name] if data[:company_name].present?
      updates[:job_role_title] = data[:job_role_title] if data[:job_role_title].present?
      updates[:job_url] = data[:job_url] if data[:job_url].present?

      # Recruiter info
      if data[:recruiter_info].is_a?(Hash)
        updates[:recruiter_name] = data[:recruiter_info][:name] if data[:recruiter_info][:name].present?
        updates[:recruiter_company] = data[:recruiter_info][:company] if data[:recruiter_info][:company].present?
      end

      # Key details
      updates[:key_details] = data[:key_details] if data[:key_details].present?

      # Links
      updates[:extracted_links] = data[:all_links] if data[:all_links].is_a?(Array)

      # Source detection
      if data[:is_forwarded]
        updates[:source_type] = case data[:original_source]
        when "linkedin" then "linkedin_forward"
        when "referral" then "referral"
        else "other"
        end
      end

      # Store full extraction data including new domain/department fields
      updates[:extracted_data] = opportunity.extracted_data.merge(
        raw_extraction: data,
        extracted_at: Time.current.iso8601,
        company_domain: data[:company_domain],
        job_role_department: data[:job_role_department]
      ).compact
      updates[:ai_confidence_score] = data[:confidence_score]

      opportunity.update!(updates)
    end

    # Notifies of extraction errors via ExceptionNotifier
    #
    # @param exception [Exception] The exception
    # @param provider_name [String, nil] Provider name if applicable
    def notify_extraction_error(exception, provider_name = nil)
      ExceptionNotifier.notify(exception, {
        context: "ai_email_extraction",
        severity: "error",
        ai_context: {
          operation: "email_extraction",
          provider_name: provider_name,
          opportunity_id: opportunity&.id
        }
      })
    end
  end
end
