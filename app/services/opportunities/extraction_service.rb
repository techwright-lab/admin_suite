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
class ExtractionService < ApplicationService
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
    notify_error(
      e,
      context: "opportunity_extraction",
      user: opportunity&.user,
      opportunity_id: opportunity&.id
    )
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
      vars = {
        subject: subject,
        body: body.truncate(4000)
      }

      Ai::PromptBuilderService.new(
        prompt_class: Ai::EmailExtractionPrompt,
        variables: vars
      ).run
    end

    # Extracts data using LLM providers
    #
    # @param prompt [String] The extraction prompt
    # @return [Hash] Result with success and data
    def extract_with_llm(prompt)
      prompt_template = Ai::EmailExtractionPrompt.active_prompt
      system_message = prompt_template&.system_prompt.presence || Ai::EmailExtractionPrompt.default_system_prompt

    runner = Ai::ProviderRunnerService.new(
        provider_chain: provider_chain,
        prompt: prompt,
        content_size: (synced_email.body_preview || synced_email.snippet || "").bytesize,
        system_message: system_message,
        provider_for: method(:get_provider_instance),
        run_options: { max_tokens: 2000, temperature: 0.1 },
        logger_builder: lambda { |provider_name, provider|
          Ai::ApiLoggerService.new(
            operation_type: :email_extraction,
            loggable: opportunity,
            provider: provider_name,
            model: provider.respond_to?(:model_name) ? provider.model_name : "unknown",
            llm_prompt: prompt_template
          )
      },
      operation: :email_extraction,
      loggable: opportunity,
      user: opportunity&.user,
      error_context: {
        severity: "warning",
        opportunity_id: opportunity&.id
      }
      )

      result = runner.run do |response|
        parsed = parse_response(response[:content])
        log_data = {
          confidence: parsed&.dig(:confidence_score),
          company_name: parsed&.dig(:company_name),
          job_role_title: parsed&.dig(:job_role_title),
          job_url: parsed&.dig(:job_url)
        }.compact

        confidence = parsed[:confidence_score].to_f
        accept = confidence >= 0.5
        [ parsed, log_data, accept ]
      end

      return { success: true, data: result[:parsed], provider: result[:provider] } if result[:success]

      { success: false, error: "All providers failed or returned low confidence" }
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
end
end
