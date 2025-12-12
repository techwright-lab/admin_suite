# frozen_string_literal: true

module Resumes
  # Service for AI-powered skill extraction from resume text
  #
  # Uses configured LLM providers to extract structured skill data,
  # with automatic fallback to alternative providers on failure.
  # Logs all LLM calls to Ai::LlmApiLog for observability.
  #
  # @example
  #   extractor = Resumes::AiSkillExtractorService.new(user_resume)
  #   result = extractor.extract
  #   if result[:success]
  #     result[:skills].each do |skill|
  #       puts "#{skill[:name]}: #{skill[:proficiency]}/5"
  #     end
  #   end
  #
  class AiSkillExtractorService
    attr_reader :user_resume

    # Minimum confidence threshold to accept extraction
    MIN_CONFIDENCE = 0.6

    # Initialize the service
    #
    # @param user_resume [UserResume] The resume to analyze
    def initialize(user_resume)
      @user_resume = user_resume
    end

    # Extracts skills from the resume text using AI
    #
    # @return [Hash] Result with :success, :skills, :summary, :confidence keys
    def extract
      text = user_resume.parsed_text
      return error_result("No parsed text available") if text.blank?

      prompt = build_extraction_prompt(text)
      result = extract_with_providers(prompt, text.bytesize)

      return error_result(result[:error]) unless result[:success]

      # Store raw AI response
      user_resume.update!(extracted_data: result[:raw_response])

      success_result(result)
    rescue StandardError => e
      notify_extraction_error(e)
      error_result(e.message)
    end

    private

    # Extracts using provider chain with fallback
    #
    # @param prompt [String] The extraction prompt
    # @param content_size [Integer] Size of resume text in bytes
    # @return [Hash] Extraction result
    def extract_with_providers(prompt, content_size)
      provider_chain.each do |provider_name|
        result = try_provider(provider_name, prompt, content_size)
        next unless result

        if result[:confidence] && result[:confidence] >= MIN_CONFIDENCE
          return result.merge(success: true)
        end
      end

      { success: false, error: "All providers failed or returned low confidence" }
    end

    # Tries a single provider
    #
    # @param provider_name [String] Provider name
    # @param prompt [String] Extraction prompt
    # @param content_size [Integer] Size of content in bytes
    # @return [Hash, nil] Result or nil on failure
    def try_provider(provider_name, prompt, content_size)
      provider = get_provider_instance(provider_name)

      unless provider.available?
        Rails.logger.info("Resume skill extractor: #{provider_name} unavailable")
        return nil
      end

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = provider.run(prompt)
      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      if response[:rate_limit]
        Rails.logger.warn("Resume skill extractor: #{provider_name} rate limited")
        log_extraction_result(provider_name, response[:model], response, nil, latency_ms, prompt, content_size)
        return nil
      end

      if response[:error]
        Rails.logger.warn("Resume skill extractor: #{provider_name} error - #{response[:error]}")
        log_extraction_result(provider_name, response[:model], response, nil, latency_ms, prompt, content_size)
        return nil
      end

      parsed = parse_response(response[:content])

      # Log the extraction result
      log_extraction_result(provider_name, response[:model], response, parsed, latency_ms, prompt, content_size)

      parsed.merge(
        provider: provider_name,
        model: response[:model],
        raw_response: response[:content]
      )
    rescue StandardError => e
      Rails.logger.error("Resume skill extractor: #{provider_name} exception - #{e.message}")
      notify_extraction_error(e, provider_name)
      nil
    end

    # Logs the extraction result to Ai::LlmApiLog
    #
    # @param provider_name [String] Provider name
    # @param model [String] Model identifier
    # @param response [Hash] Raw LLM response
    # @param parsed [Hash, nil] Parsed response data
    # @param latency_ms [Integer] Latency in milliseconds
    # @param prompt [String] The prompt used
    # @param content_size [Integer] Size of content in bytes
    def log_extraction_result(provider_name, model, response, parsed, latency_ms, prompt, content_size)
      prompt_template = Ai::ResumeSkillExtractionPrompt.active_prompt

      logger = Ai::ApiLoggerService.new(
        operation_type: :resume_extraction,
        loggable: user_resume,
        provider: provider_name,
        model: model || "unknown",
        llm_prompt: prompt_template
      )

      log_data = {
        confidence: parsed&.dig(:confidence),
        input_tokens: response[:input_tokens],
        output_tokens: response[:output_tokens],
        error: response[:error],
        rate_limit: response[:rate_limit]
      }

      # Add parsed fields for successful extractions
      if parsed.present? && parsed[:skills].present?
        log_data.merge!(
          skills: parsed[:skills],
          summary: parsed[:summary],
          strengths: parsed[:strengths],
          domains: parsed[:domains]
        )
      end

      logger.record_result(
        log_data,
        latency_ms: latency_ms,
        prompt: prompt,
        content_size: content_size
      )
    rescue => e
      Rails.logger.warn("Failed to log resume extraction result: #{e.message}")
    end

    # Builds the extraction prompt
    #
    # @param text [String] Resume text
    # @return [String] Complete prompt
    def build_extraction_prompt(text)
      prompt_template = Ai::ResumeSkillExtractionPrompt.active_prompt

      if prompt_template
        prompt_template.build_prompt(resume_text: text.truncate(15000))
      else
        Ai::ResumeSkillExtractionPrompt.default_prompt_template
          .gsub("{{resume_text}}", text.truncate(15000))
      end
    end

    # Parses the AI response
    #
    # @param response_text [String] Raw AI response
    # @return [Hash] Parsed data
    def parse_response(response_text)
      return { skills: [], error: "No response" } unless response_text.present?

      # Extract JSON from response (handle potential markdown wrapping)
      json_match = response_text.match(/\{.*\}/m)
      return { skills: [], error: "No JSON found in response" } unless json_match

      data = JSON.parse(json_match[0])
      normalize_parsed_data(data)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse skill extraction response: #{e.message}")
      { skills: [], error: "Invalid JSON response" }
    end

    # Normalizes parsed data
    #
    # @param data [Hash] Raw parsed data
    # @return [Hash] Normalized data
    def normalize_parsed_data(data)
      skills = (data["skills"] || []).map do |skill|
        {
          name: skill["name"]&.strip,
          category: normalize_category(skill["category"]),
          proficiency: skill["proficiency"]&.to_i&.clamp(1, 5) || 3,
          confidence: skill["confidence"]&.to_f&.clamp(0.0, 1.0) || 0.5,
          evidence: skill["evidence"]&.truncate(500),
          years: skill["years"]&.to_i
        }
      end.reject { |s| s[:name].blank? }

      work_history = (data["work_history"] || []).map do |entry|
        {
          company: entry["company"]&.strip,
          role: entry["role"]&.strip,
          duration: entry["duration"]&.strip
        }
      end.reject { |e| e[:company].blank? && e[:role].blank? }

      {
        skills: skills,
        work_history: work_history,
        summary: data["summary"],
        confidence: data["overall_confidence"]&.to_f || 0.5,
        strengths: Array(data["strengths"]),
        domains: Array(data["domains"]),
        resume_date: parse_resume_date(data["resume_date"]),
        resume_date_confidence: data["resume_date_confidence"],
        resume_date_source: data["resume_date_source"]
      }
    end

    # Parses resume date string to Date object
    #
    # @param date_string [String, nil] Date in YYYY-MM-DD format
    # @return [Date, nil] Parsed date or nil
    def parse_resume_date(date_string)
      return nil if date_string.blank?

      Date.parse(date_string)
    rescue ArgumentError
      nil
    end

    # Normalizes category to valid option
    #
    # @param category [String] Raw category
    # @return [String] Normalized category
    def normalize_category(category)
      valid_categories = ResumeSkill::CATEGORIES
      return "Other" if category.blank?

      # Try exact match first
      return category if valid_categories.include?(category)

      # Try case-insensitive match
      match = valid_categories.find { |c| c.downcase == category.downcase }
      return match if match

      # Default to Other
      "Other"
    end

    # Returns the provider chain
    #
    # @return [Array<String>] Provider names in priority order
    def provider_chain
      LlmProviders::ProviderConfigHelper.all_providers
    end

    # Gets a provider instance
    #
    # @param provider_name [String] Provider name
    # @return [LlmProviders::BaseProvider] Provider instance
    def get_provider_instance(provider_name)
      case provider_name.to_s.downcase
      when "openai" then LlmProviders::OpenaiProvider.new
      when "anthropic" then LlmProviders::AnthropicProvider.new
      when "ollama" then LlmProviders::OllamaProvider.new
      else raise ArgumentError, "Unknown provider: #{provider_name}"
      end
    end

    # Builds success result
    #
    # @param result [Hash] Extraction result
    # @return [Hash]
    def success_result(result)
      {
        success: true,
        skills: result[:skills],
        work_history: result[:work_history] || [],
        summary: result[:summary],
        confidence: result[:confidence],
        strengths: result[:strengths],
        domains: result[:domains],
        resume_date: result[:resume_date],
        resume_date_confidence: result[:resume_date_confidence],
        resume_date_source: result[:resume_date_source],
        provider: result[:provider],
        model: result[:model]
      }
    end

    # Builds error result
    #
    # @param message [String] Error message
    # @return [Hash]
    def error_result(message)
      {
        success: false,
        error: message,
        skills: []
      }
    end

    # Notifies of extraction errors via ExceptionNotifier
    #
    # @param exception [Exception] The exception
    # @param provider_name [String, nil] Provider name if applicable
    def notify_extraction_error(exception, provider_name = nil)
      ExceptionNotifier.notify(exception, {
        context: "ai_resume_extraction",
        severity: "error",
        ai_context: {
          operation: "resume_extraction",
          provider_name: provider_name,
          user_resume_id: user_resume&.id
        }
      })
    end
  end
end
