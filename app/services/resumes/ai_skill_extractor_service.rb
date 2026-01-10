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

      existing_extracted_data = coerce_extracted_data_hash(user_resume.extracted_data)

      # Store structured extraction output for traceability and downstream profile features.
      #
      # Keep both:
      # - parsed: normalized, structured output used by the app
      # - raw_response: original assistant text (best-effort, truncated by DB logger elsewhere)
      user_resume.update!(
        extracted_data: existing_extracted_data.merge(
          "resume_extraction" => {
            "extracted_at" => Time.current.iso8601,
            "parsed" => {
              "skills" => result[:skills],
              "work_history" => result[:work_history],
              "summary" => result[:summary],
              "overall_confidence" => result[:confidence],
              "strengths" => result[:strengths],
              "domains" => result[:domains],
              "resume_date" => result[:resume_date],
              "resume_date_confidence" => result[:resume_date_confidence],
              "resume_date_source" => result[:resume_date_source]
            },
            "raw_response" => result[:raw_response].to_s.truncate(50_000)
          }
        )
      )

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
      prompt_template = Ai::ResumeSkillExtractionPrompt.active_prompt
      system_message = prompt_template&.system_prompt.presence || Ai::ResumeSkillExtractionPrompt.default_system_prompt

      unless provider.available?
        Rails.logger.info("Resume skill extractor: #{provider_name} unavailable")
        return nil
      end

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = provider.run(prompt, system_message: system_message)
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
        rate_limit: response[:rate_limit],
        provider_request: response[:provider_request],
        provider_response: response[:provider_response],
        provider_error_response: response[:provider_error_response],
        http_status: response[:http_status],
        response_headers: response[:response_headers],
        provider_endpoint: response[:provider_endpoint]
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

      data = extract_json_object(response_text)
      return { skills: [], error: "No JSON found in response" } unless data

      normalize_parsed_data(data)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse skill extraction response: #{e.message}")
      { skills: [], error: "Invalid JSON response" }
    end

    # Coerces extracted_data into a Hash.
    #
    # Older records may have extracted_data stored as a JSON string in a jsonb column.
    #
    # @param value [Object]
    # @return [Hash]
    def coerce_extracted_data_hash(value)
      return {} if value.blank?
      return value if value.is_a?(Hash)

      if value.is_a?(String)
        parsed = (JSON.parse(value) rescue nil)
        return parsed if parsed.is_a?(Hash)
      end

      {}
    end

    # Extracts a JSON object from an LLM response string.
    #
    # Handles:
    # - raw JSON
    # - markdown fenced blocks: ```json { ... } ```
    # - extra prose around JSON
    #
    # @param text [String]
    # @return [Hash, nil]
    def extract_json_object(text)
      str = text.to_s

      fenced = str.match(/```json\s*(\{.*?\})\s*```/m)
      if fenced
        parsed = (JSON.parse(fenced[1]) rescue nil)
        return parsed if parsed.is_a?(Hash)
      end

      start_idx = str.index("{")
      end_idx = str.rindex("}")
      return nil if start_idx.nil? || end_idx.nil? || end_idx <= start_idx

      candidate = str[start_idx..end_idx]
      parsed = (JSON.parse(candidate) rescue nil)
      parsed.is_a?(Hash) ? parsed : nil
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

      work_history = Array(data["work_history"]).map do |entry|
        normalize_work_history_entry(entry)
      end.compact

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

    # Normalizes an extracted work history entry.
    #
    # Supports both legacy (company/role/duration) and expanded schema:
    # start_date/end_date/current/responsibilities/highlights/skills_used/company_domain/role_department.
    #
    # @param entry [Hash]
    # @return [Hash, nil]
    def normalize_work_history_entry(entry)
      return nil unless entry.is_a?(Hash)

      company = (entry["company"] || entry[:company]).to_s.strip
      role = (entry["role"] || entry["title"] || entry[:role] || entry[:title]).to_s.strip
      duration_text = (entry["duration"] || entry[:duration]).to_s.strip

      # New fields for domain and department
      company_domain = (entry["company_domain"] || entry[:company_domain]).to_s.strip.presence
      role_department = normalize_department(entry["role_department"] || entry[:role_department])

      start_date = parse_flexible_date(entry["start_date"] || entry[:start_date] || entry["start"] || entry[:start])
      end_date = parse_flexible_date(entry["end_date"] || entry[:end_date] || entry["end"] || entry[:end])
      current =
        if entry.key?("current") || entry.key?(:current)
          !!(entry["current"] || entry[:current])
        else
          false
        end

      responsibilities = normalize_text_array(entry["responsibilities"] || entry[:responsibilities] || entry["responsibility"] || entry[:responsibility])
      highlights = normalize_text_array(entry["highlights"] || entry[:highlights] || entry["achievements"] || entry[:achievements])

      skills_used = normalize_skill_refs(
        entry["skills_used"] || entry[:skills_used] ||
        entry["skills"] || entry[:skills] ||
        entry["technologies"] || entry[:technologies]
      )

      normalized = {
        company: company.presence,
        company_domain: company_domain,
        role: role.presence,
        role_department: role_department,
        duration: duration_text.presence,
        start_date: start_date,
        end_date: end_date,
        current: current,
        responsibilities: responsibilities,
        highlights: highlights,
        skills_used: skills_used
      }.compact

      return nil if normalized.except(:responsibilities, :highlights, :skills_used, :current, :company_domain, :role_department).blank?

      # Always include these arrays/flags for consistent downstream usage.
      normalized[:responsibilities] ||= []
      normalized[:highlights] ||= []
      normalized[:skills_used] ||= []
      normalized[:current] = !!normalized[:current]
      normalized
    end

    # Normalizes department name to match our valid departments
    #
    # @param department [String, nil]
    # @return [String, nil]
    def normalize_department(department)
      return nil if department.blank?

      dept = department.to_s.strip

      valid_departments = [
        "Engineering", "Product", "Design", "Data Science", "DevOps/SRE",
        "Sales", "Marketing", "Customer Success", "Finance", "HR/People",
        "Legal", "Operations", "Executive", "Research", "QA/Testing",
        "Security", "IT", "Content", "Other"
      ]

      # Exact match
      return dept if valid_departments.include?(dept)

      # Case-insensitive match
      matched = valid_departments.find { |d| d.downcase == dept.downcase }
      return matched if matched

      # Partial match for common variations
      dept_lower = dept.downcase
      return "Engineering" if dept_lower.include?("engineer") || dept_lower.include?("develop") || dept_lower.include?("tech")
      return "Product" if dept_lower.include?("product")
      return "Design" if dept_lower.include?("design") || dept_lower.include?("ux") || dept_lower.include?("ui")
      return "Data Science" if dept_lower.include?("data") || dept_lower.include?("analyt")
      return "DevOps/SRE" if dept_lower.include?("devops") || dept_lower.include?("sre") || dept_lower.include?("infrastructure")
      return "Sales" if dept_lower.include?("sales")
      return "Marketing" if dept_lower.include?("market") || dept_lower.include?("growth")
      return "HR/People" if dept_lower.include?("hr") || dept_lower.include?("human") || dept_lower.include?("people") || dept_lower.include?("talent")
      return "Finance" if dept_lower.include?("finance") || dept_lower.include?("account")
      return "Legal" if dept_lower.include?("legal")
      return "Executive" if dept_lower.include?("executive") || dept_lower.include?("leadership") || dept_lower.include?("c-suite")
      return "QA/Testing" if dept_lower.include?("qa") || dept_lower.include?("quality") || dept_lower.include?("test")
      return "Security" if dept_lower.include?("security")
      return "Customer Success" if dept_lower.include?("customer") || dept_lower.include?("support")

      nil
    end

    # Parses flexible date formats (YYYY-MM-DD, YYYY-MM, YYYY).
    #
    # @param value [String, nil]
    # @return [Date, nil]
    def parse_flexible_date(value)
      str = value.to_s.strip
      return nil if str.blank?

      if str.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        Date.parse(str)
      elsif str.match?(/\A\d{4}-\d{2}\z/)
        year, month = str.split("-").map(&:to_i)
        Date.new(year, month, 1)
      elsif str.match?(/\A\d{4}\z/)
        Date.new(str.to_i, 1, 1)
      else
        Date.parse(str)
      end
    rescue ArgumentError
      nil
    end

    # Normalizes a value into an array of non-empty strings.
    #
    # @param value [Object]
    # @return [Array<String>]
    def normalize_text_array(value)
      Array(value).map { |v| v.to_s.strip }.reject(&:blank?).first(50)
    end

    # Normalizes a “skills used” payload into a list of hashes.
    #
    # Supports:
    # - ["Ruby", "Postgres"]
    # - [{ "name": "Ruby", "evidence": "...", "confidence": 0.8 }, ...]
    #
    # @param value [Object]
    # @return [Array<Hash>]
    def normalize_skill_refs(value)
      Array(value).map do |item|
        if item.is_a?(Hash)
          name = (item["name"] || item[:name] || item["skill"] || item[:skill]).to_s.strip
          next nil if name.blank?

          {
            name: name,
            confidence: (item["confidence"] || item[:confidence])&.to_f,
            evidence: (item["evidence"] || item[:evidence]).to_s.strip.presence
          }.compact
        else
          name = item.to_s.strip
          next nil if name.blank?
          { name: name }
        end
      end.compact.uniq { |h| h[:name].to_s.downcase }.first(50)
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
