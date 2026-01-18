# frozen_string_literal: true

module Signals
  # Service for AI-powered extraction of actionable signals from synced emails
  #
  # Uses configured LLM providers to extract structured intelligence including
  # company info, recruiter details, job information, relevant links, and
  # suggested actions from email content.
  #
  # @example
  #   service = Signals::ExtractionService.new(synced_email)
  #   result = service.extract
  #   if result[:success]
  #     # Email has been updated with extracted signals
  #   end
  #
  class ExtractionService < ApplicationService
    attr_reader :synced_email

    # Minimum confidence score to accept extraction results
    MIN_CONFIDENCE_SCORE = 0.5
    MIN_PREVIEW_LENGTH = 200

    # Initialize the service
    #
    # @param synced_email [SyncedEmail] The email to extract signals from
    def initialize(synced_email)
      @synced_email = synced_email
    end

    # Extracts signals from the email using AI
    #
    # @return [Hash] Result with success status and extracted data
    def extract
      return skip_extraction("No email content available") unless email_content_available?
      return skip_extraction("Email type not suitable for extraction") unless should_extract?

      synced_email.mark_extraction_processing!

      # Build prompt with email content
      prompt = build_prompt

      # Try extraction with LLM providers
      result = extract_with_llm(prompt)

      if result[:success]
        update_email_with_signals(result[:data])
        result
      else
        synced_email.mark_extraction_failed!(result[:error])
        { success: false, error: result[:error] || "Extraction failed" }
      end
    rescue StandardError => e
      notify_error(
        e,
        context: "signal_extraction_service",
        user: synced_email&.user,
        synced_email_id: synced_email&.id,
        email_type: synced_email&.email_type
      )
      synced_email.mark_extraction_failed!(e.message)
      { success: false, error: e.message }
    end

    private

    # Checks if email content is available for extraction
    #
    # @return [Boolean]
    def email_content_available?
      synced_email.body_preview.present? ||
        synced_email.body_html.present? ||
        synced_email.snippet.present? ||
        synced_email.subject.present?
    end

    # Determines if this email should have signals extracted
    # Skip extraction for clearly irrelevant emails
    #
    # @return [Boolean]
    def should_extract?
      # Skip auto-ignored and ignored emails
      return false if synced_email.auto_ignored? || synced_email.ignored?

      # Skip emails classified as "other" that aren't matched
      return false if synced_email.email_type == "other" && !synced_email.matched?

      true
    end

    # Skips extraction with a reason
    #
    # @param reason [String]
    # @return [Hash]
    def skip_extraction(reason)
      synced_email.mark_extraction_skipped!
      { success: false, skipped: true, reason: reason }
    end

    # Builds the extraction prompt with email content
    #
    # @return [String]
    def build_prompt
      subject = synced_email.subject || "(No subject)"
      body = extract_body_content
      from_email = synced_email.from_email || ""
      from_name = synced_email.from_name || ""
      email_type = synced_email.email_type || "unknown"
      vars = {
        subject: subject,
        body: body.truncate(6000),
        from_email: from_email,
        from_name: from_name,
        email_type: email_type
      }

      Ai::PromptBuilderService.new(
        prompt_class: Ai::SignalExtractionPrompt,
        variables: vars
      ).run
    end

    # Extracts the best available body content
    #
    # @return [String]
    def extract_body_content
      # Prefer preview if it's substantial; otherwise fall back to cleaned HTML text
      if synced_email.body_preview.present? && synced_email.body_preview.length >= MIN_PREVIEW_LENGTH
        normalize_text(synced_email.body_preview)
      elsif synced_email.body_html.present?
        normalize_text(extract_text_from_html(synced_email.body_html))
      else
        normalize_text(synced_email.snippet || "")
      end
    end

    # Extracts data using LLM providers
    #
    # @param prompt [String] The extraction prompt
    # @return [Hash] Result with success and data
    def extract_with_llm(prompt)
      prompt_template = Ai::SignalExtractionPrompt.active_prompt
      system_message = prompt_template&.system_prompt.presence || Ai::SignalExtractionPrompt.default_system_prompt

      runner = Ai::ProviderRunnerService.new(
        provider_chain: provider_chain,
        prompt: prompt,
        content_size: extract_body_content.bytesize,
        system_message: system_message,
        provider_for: method(:get_provider_instance),
        run_options: { max_tokens: 2000, temperature: 0.1 },
        logger_builder: lambda { |provider_name, provider|
          Ai::ApiLoggerService.new(
            operation_type: :signal_extraction,
            loggable: synced_email,
            provider: provider_name,
            model: provider.respond_to?(:model_name) ? provider.model_name : "unknown",
            llm_prompt: prompt_template
          )
        },
        operation: :signal_extraction,
        loggable: synced_email,
        user: synced_email&.user,
        error_context: {
          severity: "warning",
          synced_email_id: synced_email&.id,
          email_type: synced_email&.email_type
        }
      )

      result = runner.run do |response|
        parsed = parse_response(response[:content])
        log_data = {
          confidence: parsed&.dig(:confidence_score),
          company_name: parsed&.dig(:company, :name),
          recruiter_name: parsed&.dig(:recruiter, :name),
          job_title: parsed&.dig(:job, :title),
          suggested_actions: parsed&.dig(:suggested_actions)
        }.compact
        accept = parsed[:confidence_score] && parsed[:confidence_score] >= MIN_CONFIDENCE_SCORE
        [ parsed, log_data, accept ]
      end

      return { success: true, data: result[:parsed], provider: result[:provider] } if result[:success]

      { success: false, error: result[:error] || "All providers failed or returned low confidence" }
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
      parsed = Ai::ResponseParserService.new(response_text).parse(symbolize: true)
      parsed || { confidence_score: 0.0 }
    end

    # Updates the email with extracted signal data
    #
    # @param data [Hash] Extracted data from LLM
    # @return [void]
    def update_email_with_signals(data)
      extracted = {}

      # Company information
      if data[:company].is_a?(Hash)
        extracted[:signal_company_name] = data[:company][:name] if data[:company][:name].present?
        extracted[:signal_company_website] = data[:company][:website] if data[:company][:website].present?
        extracted[:signal_company_careers_url] = data[:company][:careers_url] if data[:company][:careers_url].present?
        extracted[:signal_company_domain] = data[:company][:domain] if data[:company][:domain].present?
      end

      # Recruiter information
      if data[:recruiter].is_a?(Hash)
        extracted[:signal_recruiter_name] = data[:recruiter][:name] if data[:recruiter][:name].present?
        extracted[:signal_recruiter_email] = data[:recruiter][:email] if data[:recruiter][:email].present?
        extracted[:signal_recruiter_title] = data[:recruiter][:title] if data[:recruiter][:title].present?
        extracted[:signal_recruiter_linkedin] = data[:recruiter][:linkedin_url] if data[:recruiter][:linkedin_url].present?
      end

      # Job information
      if data[:job].is_a?(Hash)
        extracted[:signal_job_title] = data[:job][:title] if data[:job][:title].present?
        extracted[:signal_job_department] = data[:job][:department] if data[:job][:department].present?
        extracted[:signal_job_location] = data[:job][:location] if data[:job][:location].present?
        extracted[:signal_job_url] = data[:job][:url] if data[:job][:url].present?
        extracted[:signal_job_salary_hint] = data[:job][:salary_hint] if data[:job][:salary_hint].present?
      end

      # Action links (LLM-classified URLs with dynamic labels)
      if data[:action_links].is_a?(Array)
        # Normalize and filter links to remove duplicates/noise
        normalized_links = data[:action_links].map do |link|
          {
            "url" => link[:url].to_s,
            "action_label" => link[:action_label].to_s,
            "priority" => (link[:priority] || 5).to_i
          }
        end.select { |link| link["url"].present? && link["action_label"].present? }

        extracted[:signal_action_links] = filter_action_links(normalized_links)
      end

      # Suggested backend actions
      if data[:suggested_actions].is_a?(Array)
        # Filter to only valid actions
        valid_actions = data[:suggested_actions] & SyncedEmail::SUGGESTED_ACTIONS
        extracted[:signal_suggested_actions] = valid_actions if valid_actions.any?
      end

      # Store additional metadata
      extracted[:key_insights] = data[:key_insights] if data[:key_insights].present?
      extracted[:is_forwarded] = data[:is_forwarded] if data[:is_forwarded].present?
      extracted[:raw_extraction] = data
      extracted[:extracted_at] = Time.current.iso8601

      synced_email.update_extraction!(extracted, confidence: data[:confidence_score])

      # Automatically save company and recruiter information
      save_company_and_recruiter(extracted)
    end

    # Automatically saves company and recruiter information from extracted signals
    # This builds the recruiter directory and company database without user action
    #
    # @param extracted [Hash] The extracted signal data
    # @return [void]
    def save_company_and_recruiter(extracted)
      company = nil

      # Create or find company if we have a name
      if extracted[:signal_company_name].present?
        company = find_or_create_company(extracted)
      end

      # Enrich the email sender with recruiter info
      enrich_email_sender(extracted, company)
    rescue StandardError => e
      # Don't fail extraction if company/recruiter save fails
      Rails.logger.warn("Failed to save company/recruiter for email #{synced_email.id}: #{e.message}")
    end

    # Finds or creates a company from extracted signal data
    # Note: Company is a global model, not user-scoped
    #
    # @param extracted [Hash] The extracted signal data
    # @return [Company, nil]
    def find_or_create_company(extracted)
      return nil unless extracted[:signal_company_name].present?

      # Try to find existing company by name (case-insensitive)
      existing = Company.where("LOWER(name) = ?", extracted[:signal_company_name].downcase).first

      if existing
        # Update with any new info we have
        updates = {}
        updates[:website] = extracted[:signal_company_website] if extracted[:signal_company_website].present? && existing.website.blank?
        existing.update!(updates) if updates.any?
        return existing
      end

      # Create new company with extracted data
      Company.create!(
        name: extracted[:signal_company_name],
        website: extracted[:signal_company_website]
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("Failed to create company #{extracted[:signal_company_name]}: #{e.message}")
      # Try to find again in case of race condition
      Company.where("LOWER(name) = ?", extracted[:signal_company_name].downcase).first
    end

    # Enriches the email sender record with extracted recruiter information
    #
    # @param extracted [Hash] The extracted signal data
    # @param company [Company, nil] The associated company
    # @return [void]
    def enrich_email_sender(extracted, company)
      # Get or create the email sender
      sender = synced_email.email_sender
      sender ||= EmailSender.find_or_create_from_email(
        synced_email.from_email,
        extracted[:signal_recruiter_name] || synced_email.from_name
      )
      return unless sender

      updates = {}

      # Update name if we have a better one from extraction
      if extracted[:signal_recruiter_name].present? && sender.name.blank?
        updates[:name] = extracted[:signal_recruiter_name]
      end

      # Update title from extraction (if model supports it)
      if extracted[:signal_recruiter_title].present? && sender.respond_to?(:title=)
        updates[:title] = extracted[:signal_recruiter_title]
      end

      # Update LinkedIn URL from extraction (if model supports it)
      if extracted[:signal_recruiter_linkedin].present? && sender.respond_to?(:linkedin_url=)
        updates[:linkedin_url] = extracted[:signal_recruiter_linkedin]
      end

      # Set sender type to recruiter if we detect recruiter title
      if extracted[:signal_recruiter_title].present? &&
         extracted[:signal_recruiter_title].downcase.match?(/recruit|talent|sourcing/i)
        updates[:sender_type] = "recruiter"
      end

      # Link to company if not already linked
      if company && !sender.has_company?
        updates[:auto_detected_company] = company
      end

      # Update last seen
      updates[:last_seen_at] = Time.current

      sender.update!(updates) if updates.any?

      # Link sender to email if not already
      synced_email.update!(email_sender: sender) unless synced_email.email_sender_id == sender.id
    end

    # Extracts text content from HTML while removing noisy elements.
    #
    # @param html [String]
    # @return [String]
    def extract_text_from_html(html)
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      fragment.css("style, script, noscript, head, title, meta, link").remove

      fragment.css("*[style]").each do |node|
        style = node["style"].to_s.downcase
        node.remove if style.include?("display:none") || style.include?("visibility:hidden")
      end

      fragment.traverse do |node|
        node.remove if node.comment?
      end

      fragment.text
    rescue StandardError
      ActionController::Base.helpers.strip_tags(html.to_s)
    end

    # Normalizes text by collapsing whitespace and trimming.
    #
    # @param text [String]
    # @return [String]
    def normalize_text(text)
      text.to_s.gsub(/\s+/, " ").strip
    end

    # Filters action links to remove duplicates and low-value URLs.
    #
    # @param links [Array<Hash>]
    # @return [Array<Hash>]
    def filter_action_links(links)
      return [] if links.blank?

      ignore_label_patterns = [
        /unsubscribe/i,
        /view in browser/i,
        /privacy/i,
        /terms/i,
        /learn more/i,
        /forwarding/i,
        /event details/i
      ]

      ignore_url_patterns = [
        %r{calendar\.google\.com}i,
        %r{google\.com/calendar}i,
        %r{support\.google\.com}i
      ]

      seen = {}
      links.sort_by { |link| link["priority"] || 5 }.each_with_object([]) do |link, filtered|
        url = link["url"].to_s.strip
        label = link["action_label"].to_s.strip
        next if url.blank? || label.blank?

        next if ignore_label_patterns.any? { |pattern| label.match?(pattern) }
        next if ignore_url_patterns.any? { |pattern| url.match?(pattern) } &&
                !label.match?(/schedule|reschedule|join/i)

        key = canonical_url_key(url)
        next if key.present? && seen[key]

        seen[key] = true if key.present?
        filtered << link
      end
    end

    # Canonicalizes URLs for deduplication by stripping tracking params.
    #
    # @param url [String]
    # @return [String, nil]
    def canonical_url_key(url)
      uri = URI.parse(url)
      return nil unless uri.host

      # Unwrap common redirect URLs (e.g., Google Calendar links)
      if uri.host.match?(/google\.com/i) && uri.path == "/url"
        params = URI.decode_www_form(uri.query.to_s).to_h
        redirected = params["q"] || params["url"]
        return canonical_url_key(redirected) if redirected.present?
      end

      params = URI.decode_www_form(uri.query.to_s).reject do |(key, _)|
        key.match?(/\Autm_/i) || %w[gclid fbclid mc_cid mc_eid].include?(key)
      end

      uri.query = params.any? ? URI.encode_www_form(params) : nil
      uri.fragment = nil

      normalized = "#{uri.scheme}://#{uri.host}#{uri.path}"
      normalized += "?#{uri.query}" if uri.query.present?
      normalized.sub(%r{/\z}, "")
    rescue StandardError
      nil
    end
  end
end
