# frozen_string_literal: true

module Scraping
  # Main orchestration service for job listing extraction
  #
  # Coordinates the entire extraction process:
  # 1. Check robots.txt and rate limits (before any network requests)
  # 2. Detect job board type
  # 3. Fetch HTML content
  # 4. Scrape with Nokogiri (fast, cheap)
  # 5. Try API extraction if supported
  # 6. Fall back to AI extraction
  #
  # @example
  #   orchestrator = Scraping::OrchestratorService.new(job_listing)
  #   orchestrator.call
  class OrchestratorService
    attr_reader :job_listing, :attempt, :event_recorder

    # Initialize the orchestrator with a job listing
    #
    # @param [JobListing] job_listing The job listing to extract data for
    def initialize(job_listing)
      @job_listing = job_listing
      @start_time = Time.current
      @event_recorder = nil
    end

    # Executes the extraction orchestration with step isolation
    #
    # @return [Boolean] True if extraction completed successfully
    def call
      return false unless @job_listing.url.present?

      # Ensure job listing is persisted before creating attempt
      @job_listing.save! if @job_listing.new_record?

      # Create scraping attempt record
      @attempt = create_attempt

      # Initialize event recorder for observability
      @event_recorder = EventRecorderService.new(@attempt, job_listing: @job_listing)

      log_event("extraction_started")

      # Step 1: Check permissions BEFORE any network requests
      # @event_recorder.record(:permission_check, step: 1, input: { url: @job_listing.url }) do |event|
      #   allowed = check_scraping_allowed?
      #   event.set_output(allowed: allowed)
      #   unless allowed
      #     fail_attempt_at_step("permission_check", "Scraping not allowed by robots.txt or rate limited")
      #     return false
      #   end
      #   { success: true }
      # end

      # Detect job board type (needed for API check)
      detector = JobBoardDetectorService.new(@job_listing.url)
      board_type = detector.detect
      company_slug = detector.company_slug
      job_id = detector.job_id

      @attempt.start_fetch!

      # Step 2: Fetch HTML (idempotent - uses cache if available)
      html_result = @event_recorder.record(:html_fetch, step: 2, input: { url: @job_listing.url }) do |event|
        result = execute_html_fetch_internal
        event.set_output(
          success: result[:success],
          html_size: result[:html_content]&.bytesize,
          cleaned_html_size: result[:cleaned_html]&.bytesize,
          cached: result[:cached],
          http_status: result[:http_status],
          error: result[:error]
        )
        result
      end

      unless html_result[:success]
        @event_recorder.record_failure(message: html_result[:error], error_type: "html_fetch_failed")
        fail_attempt_at_step("html_fetch", html_result[:error])
        return false
      end

      html_content = html_result[:html_content]
      cleaned_html = html_result[:cleaned_html]

      # Step 3: Scrape with Nokogiri (fast, cheap)
      scraping_result = @event_recorder.record(:nokogiri_scrape, step: 3, input: { html_size: html_content&.bytesize }) do |event|
        result = execute_html_scraping_internal(html_content)
        event.set_output(
          extracted_fields: result.keys,
          title: result[:title],
          company: result[:company_name],
          location: result[:location]
        )
        result
      end

      update_job_listing_preliminary(scraping_result) if scraping_result.any?

      # Step 4: Try API extraction (idempotent)
      if should_try_api?(detector, company_slug)
        api_result = @event_recorder.record(:api_extraction, step: 4, input: { board_type: board_type, company_slug: company_slug, job_id: job_id }) do |event|
          result = execute_api_extraction_internal(board_type, company_slug, job_id)
          if result
            event.set_output(
              success: result[:confidence].present? && result[:confidence] >= 0.7,
              confidence: result[:confidence],
              provider: board_type,
              extracted_fields: result.keys
            )
          else
            event.set_output(success: false, error: "No result from API")
          end
          result
        end

        if api_result && api_result[:confidence] && api_result[:confidence] >= 0.7
          # Record data update
          @event_recorder.record_simple(:data_update, status: :success, input: { source: "api" }, output: { confidence: api_result[:confidence] })
          update_job_listing(api_result)
          @event_recorder.record_completion(summary: { method: "api", confidence: api_result[:confidence], provider: board_type })
          complete_attempt(api_result)
          return true
        end
        # API failed or low confidence, continue to AI extraction
      else
        @event_recorder.record_skipped(:api_extraction, reason: "API not supported for this board type", metadata: { board_type: board_type })
      end

      # Step 5: Try AI extraction (idempotent - uses cached HTML)
      @attempt.start_extract!
      ai_result = @event_recorder.record(:ai_extraction, step: 5, input: { html_size: html_content&.bytesize, cleaned_html_size: cleaned_html&.bytesize }) do |event|
        result = execute_ai_extraction_internal(html_content: html_content, cleaned_html: cleaned_html)
        event.set_output(
          success: result[:confidence].present? && result[:confidence] >= 0.7,
          confidence: result[:confidence],
          provider: result[:provider],
          model: result[:model],
          tokens_used: result[:tokens_used],
          extracted_fields: result.keys.select { |k| result[k].present? },
          error: result[:error]
        )
        result
      end

      if ai_result && ai_result[:confidence] && ai_result[:confidence] >= 0.7
        # Record data update
        @event_recorder.record_simple(:data_update, status: :success, input: { source: "ai" }, output: { confidence: ai_result[:confidence] })
        update_job_listing(ai_result)
        @event_recorder.record_completion(summary: { method: "ai", confidence: ai_result[:confidence], provider: ai_result[:provider], model: ai_result[:model] })
        complete_attempt(ai_result)
        true
      else
        @event_recorder.record_failure(message: "Low confidence: #{ai_result[:confidence] || 0.0}", error_type: "low_confidence", details: { confidence: ai_result[:confidence] })
        fail_attempt_at_step("ai_extraction", "Low confidence: #{ai_result[:confidence] || 0.0}")
        false
      end
    rescue => e
      log_error("Orchestration failed", e)
      @event_recorder&.record_failure(message: e.message, error_type: e.class.name, details: { backtrace: e.backtrace&.first(5) })
      fail_attempt_at_step("orchestration", e.message)
      raise
    end

    private

    # Creates a new scraping attempt record
    #
    # @return [ScrapingAttempt] The created attempt
    def create_attempt
      @job_listing.scraping_attempts.create!(
        url: @job_listing.url,
        domain: extract_domain(@job_listing.url),
        status: :pending
      )
    end

    # Extracts domain from URL
    #
    # @param [String] url The URL
    # @return [String] Domain name
    def extract_domain(url)
      URI.parse(url).host
    rescue
      "unknown"
    end

    # Checks if API extraction should be attempted
    #
    # @param [JobBoardDetectorService] detector The job board detector
    # @param [String, nil] company_slug Company identifier
    # @return [Boolean] True if API extraction should be tried
    def should_try_api?(detector, company_slug)
      detector.api_supported? && company_slug.present?
    end

    # Gets the appropriate API fetcher for a board type
    #
    # @param [Symbol] board_type The board type
    # @return [ApiFetchers::BaseFetcher, nil] Fetcher instance or nil
    def get_api_fetcher(board_type)
      case board_type
      when :greenhouse
        ApiFetchers::GreenhouseFetcher.new
      when :lever
        ApiFetchers::LeverFetcher.new
      else
        nil
      end
    end

    # Checks if scraping is allowed (robots.txt + rate limiting)
    #
    # @return [Boolean] True if allowed
    def check_scraping_allowed?
      domain = extract_domain(@job_listing.url)

      # Check robots.txt
      robots_checker = RobotsTxtCheckerService.new(@job_listing.url)
      unless robots_checker.allowed?
        return false
      end

      # Check rate limiting
      rate_limiter = RateLimiterService.new(domain)
      unless rate_limiter.allowed?
        return false
      end

      # Record this request
      rate_limiter.record_request!
      true
    end

    # Executes HTML fetch (services handle their own logging)
    #
    # @return [Hash] Result with html_content and cached_data
    def execute_html_fetch
      execute_html_fetch_internal
    rescue => e
      log_error("HTML fetch failed", e)

      ExceptionNotifier.notify(e, {
        context: "html_fetch",
        severity: "error",
        url: @job_listing.url,
        job_listing_id: @job_listing.id
      })

      { success: false, error: e.message }
    end

    # Internal HTML fetch without exception handling (for event recording)
    #
    # @return [Hash] Result with html_content and cached_data
    def execute_html_fetch_internal
      fetcher = HtmlFetcherService.new(@job_listing, scraping_attempt: @attempt)
      fetcher.call
    end

    # Executes HTML scraping with Nokogiri (services handle their own logging)
    #
    # @param [String] html_content The HTML content
    # @return [Hash] Extracted data
    def execute_html_scraping(html_content)
      execute_html_scraping_internal(html_content)
    rescue => e
      log_error("HTML scraping failed", e)
      {}
    end

    # Internal HTML scraping without exception handling (for event recording)
    #
    # @param [String] html_content The HTML content
    # @return [Hash] Extracted data
    def execute_html_scraping_internal(html_content)
      return {} if html_content.blank?

      extractor = Scraping::HtmlScrapingService.new(job_listing: @job_listing, scraping_attempt: @attempt)
      extractor.extract(html_content, @job_listing.url)
    end

    # Executes API extraction (services handle their own logging)
    #
    # @param [Symbol] board_type The board type
    # @param [String] company_slug Company identifier
    # @param [String] job_id Job identifier
    # @return [Hash, nil] Extracted data or nil
    def execute_api_extraction(board_type, company_slug, job_id)
      execute_api_extraction_internal(board_type, company_slug, job_id)
    rescue => e
      log_error("API extraction failed", e)

      ExceptionNotifier.notify(e, {
        context: "api_extraction",
        severity: "error",
        board_type: board_type,
        company_slug: company_slug,
        job_id: job_id,
        url: @job_listing.url
      })

      nil
    end

    # Internal API extraction without exception handling (for event recording)
    #
    # @param [Symbol] board_type The board type
    # @param [String] company_slug Company identifier
    # @param [String] job_id Job identifier
    # @return [Hash, nil] Extracted data or nil
    def execute_api_extraction_internal(board_type, company_slug, job_id)
      fetcher = get_api_fetcher(board_type)
      return nil unless fetcher

      fetcher.fetch(
        url: @job_listing.url,
        company_slug: company_slug,
        job_id: job_id
      )
    end

    # Executes AI extraction (services handle their own logging)
    #
    # @param [String, nil] html_content Pre-fetched HTML content
    # @param [String, nil] cleaned_html Pre-cleaned HTML content
    # @return [Hash] Extracted data
    def execute_ai_extraction(html_content: nil, cleaned_html: nil)
      execute_ai_extraction_internal(html_content: html_content, cleaned_html: cleaned_html)
    rescue => e
      log_error("AI extraction failed", e)

      ExceptionNotifier.notify(e, {
        context: "ai_extraction",
        severity: "error",
        url: @job_listing.url,
        job_listing_id: @job_listing.id
      })

      { error: e.message, confidence: 0.0 }
    end

    # Internal AI extraction without exception handling (for event recording)
    #
    # @param [String, nil] html_content Pre-fetched HTML content
    # @param [String, nil] cleaned_html Pre-cleaned HTML content
    # @return [Hash] Extracted data
    def execute_ai_extraction_internal(html_content: nil, cleaned_html: nil)
      extractor = AiJobExtractorService.new(@job_listing, scraping_attempt: @attempt)
      extractor.extract(html_content: html_content, cleaned_html: cleaned_html)
    end

    # Updates job listing with preliminary data (before API/AI extraction)
    #
    # @param [Hash] preliminary_data The preliminary extracted data
    # @return [Boolean] True if updated successfully
    def update_job_listing_preliminary(preliminary_data)
      updates = {}

      # Only update fields that are present and not already set
      updates[:title] = preliminary_data[:title] if preliminary_data[:title].present? && @job_listing.title.blank?
      updates[:location] = preliminary_data[:location] if preliminary_data[:location].present? && @job_listing.location.blank?
      updates[:remote_type] = preliminary_data[:remote_type] if preliminary_data[:remote_type].present? && @job_listing.remote_type == "on_site"
      updates[:salary_min] = preliminary_data[:salary_min] if preliminary_data[:salary_min].present? && @job_listing.salary_min.blank?
      updates[:salary_max] = preliminary_data[:salary_max] if preliminary_data[:salary_max].present? && @job_listing.salary_max.blank?
      updates[:salary_currency] = preliminary_data[:salary_currency] if preliminary_data[:salary_currency].present?
      updates[:description] = preliminary_data[:description] if preliminary_data[:description].present? && @job_listing.description.blank?

      # Update company if extracted and different from current
      if preliminary_data[:company_name].present?
        company = find_or_create_company(preliminary_data[:company_name])
        # Only update if it's actually a different company record
        updates[:company] = company if @job_listing.company_id.nil? || company.id != @job_listing.company_id
      end

      # Update job_role if extracted (from title or job_role_title)
      job_role_title = preliminary_data[:job_role_title] || preliminary_data[:title]
      if job_role_title.present?
        job_role = find_or_create_job_role(job_role_title)
        # Only update if it's actually a different job role record
        updates[:job_role] = job_role if @job_listing.job_role_id.nil? || job_role.id != @job_listing.job_role_id
      end

      return false if updates.empty?

      @job_listing.update(updates)
    end

    # Updates the job listing with extracted data
    #
    # @param [Hash] result The extracted data
    # @return [Boolean] True if updated successfully
    def update_job_listing(result)
      updates = {
        title: result[:title] || @job_listing.title,
        description: result[:description] || @job_listing.description,
        requirements: result[:requirements] || @job_listing.requirements,
        responsibilities: result[:responsibilities] || @job_listing.responsibilities,
        salary_min: result[:salary_min] || @job_listing.salary_min,
        salary_max: result[:salary_max] || @job_listing.salary_max,
        salary_currency: result[:salary_currency] || @job_listing.salary_currency,
        equity_info: result[:equity_info] || @job_listing.equity_info,
        benefits: result[:benefits] || @job_listing.benefits,
        perks: result[:perks] || @job_listing.perks,
        location: result[:location] || @job_listing.location,
        remote_type: result[:remote_type] || @job_listing.remote_type,
        custom_sections: result[:custom_sections] || @job_listing.custom_sections,
        scraped_data: build_scraped_metadata(result)
      }

      # Update company if extracted
      # Only update if we found a different company (fuzzy matching handles similar names)
      if result[:company].present?
        company = find_or_create_company(result[:company])
        # Only update if it's actually a different company record
        updates[:company] = company if @job_listing.company_id.nil? || company.id != @job_listing.company_id
      elsif result[:company_name].present?
        # Fallback to company_name from HTML scraping
        company = find_or_create_company(result[:company_name])
        # Only update if it's actually a different company record
        updates[:company] = company if @job_listing.company_id.nil? || company.id != @job_listing.company_id
      end

      # Update job_role if extracted (prefer job_role field, fallback to title)
      job_role_title = result[:job_role] || result[:title]
      if job_role_title.present?
        job_role = find_or_create_job_role(job_role_title)
        # Only update if it's actually a different job role record
        updates[:job_role] = job_role if @job_listing.job_role_id.nil? || job_role.id != @job_listing.job_role_id
      end

      @job_listing.update(updates)
    end

    # Builds scraped metadata for storage
    #
    # @param [Hash] result The extraction result
    # @return [Hash] Metadata hash
    def build_scraped_metadata(result)
      {
        status: "completed",
        extraction_method: result[:extraction_method] || "ai",
        provider: result[:provider],
        model: result[:model],
        confidence_score: result[:confidence],
        tokens_used: result[:tokens_used],
        extracted_at: Time.current.iso8601,
        duration_seconds: Time.current - @start_time
      }
    end

    # Completes the attempt successfully
    #
    # @param [Hash] result The extraction result
    def complete_attempt(result)
      return unless @attempt

      @attempt.update(
        extraction_method: result[:extraction_method] || "ai",
        provider: result[:provider],
        confidence_score: result[:confidence],
        duration_seconds: Time.current - @start_time,
        response_metadata: {
          model: result[:model],
          tokens_used: result[:tokens_used]
        }
      )
      @attempt.mark_completed!

      log_event("extraction_completed", {
        confidence: result[:confidence],
        duration: Time.current - @start_time
      })
    end

    # Marks the attempt as failed at a specific step
    #
    # @param [String] failed_step The step that failed ("html_fetch", "api_extraction", "ai_extraction", "orchestration")
    # @param [String] error_message The error message
    def fail_attempt_at_step(failed_step, error_message)
      return unless @attempt

      @attempt.update(
        failed_step: failed_step,
        error_message: error_message,
        duration_seconds: Time.current - @start_time
      )
      @attempt.mark_failed!

      log_event("extraction_failed", {
        failed_step: failed_step,
        error: error_message
      })
    end

    # Marks the attempt as failed (backward compatibility)
    #
    # @param [String] error_message The error message
    def fail_attempt(error_message)
      fail_attempt_at_step("orchestration", error_message)
    end

    # Logs a structured event
    #
    # @param [String] event_name The event name
    # @param [Hash] data Additional event data
    def log_event(event_name, data = {})
      Rails.logger.info({
        event: event_name,
        job_listing_id: @job_listing.id,
        scraping_attempt_id: @attempt&.id,
        url: @job_listing.url,
        domain: extract_domain(@job_listing.url)
      }.merge(data).to_json)
    end

    # Logs an error
    #
    # @param [String] message The error message
    # @param [Exception] exception The exception
    def log_error(message, exception)
      Rails.logger.error({
        error: message,
        exception: exception.class.name,
        message: exception.message,
        backtrace: exception.backtrace&.first(5),
        job_listing_id: @job_listing.id,
        scraping_attempt_id: @attempt&.id,
        url: @job_listing.url
      }.to_json)

      # Notify exception with scraping context
      ExceptionNotifier.notify(exception, {
        context: "scraping_orchestration",
        severity: "error",
        error_message: message,
        job_listing_id: @job_listing.id,
        scraping_attempt_id: @attempt&.id,
        url: @job_listing.url
      })
    end

    # Finds or creates a Company by name
    #
    # Uses domain/website matching first (more reliable), then falls back to name matching
    #
    # @param [String] name The company name
    # @return [Company] The company record
    def find_or_create_company(name)
      return @job_listing.company if name.blank?

      normalized_name = normalize_company_name(name)
      domain = extract_domain_from_url(@job_listing.url)

      # First, check if job listing already has a company
      # If it has a website, check domain match; otherwise check name similarity
      if @job_listing.company.present?
        existing_company = @job_listing.company

        # If both have domains, match by domain (most reliable)
        if domain.present? && existing_company.website.present?
          existing_domain = extract_domain_from_url(existing_company.website)
          return existing_company if domains_match?(domain, existing_domain)
        end

        # Otherwise, check name similarity
        existing_normalized = normalize_company_name(existing_company.name)
        return existing_company if names_similar?(normalized_name, existing_normalized)
      end

      # Try to find by domain first (most reliable)
      if domain.present?
        company = find_company_by_domain(domain)
        return company if company
      end

      # Try to find existing company by exact name match
      company = Company.find_by(name: normalized_name)
      return company if company

      # Try fuzzy matching to find similar company names
      company = find_similar_company(normalized_name)
      return company if company

      # Create new company if no match found
      Company.create!(name: normalized_name) do |c|
        # Set website from URL if available
        if domain.present?
          c.website = "https://#{domain}"
        end
      end
    end

    # Finds or creates a JobRole by title
    #
    # @param [String] title The job role title
    # @return [JobRole] The job role record
    def find_or_create_job_role(title)
      return @job_listing.job_role if title.blank?

      normalized_title = normalize_job_role_title(title)

      JobRole.find_or_create_by(title: normalized_title)
    end

    # Normalizes company name for matching
    #
    # Removes common suffixes and normalizes the name for better matching
    #
    # @param [String] name The company name
    # @return [String] Normalized name
    def normalize_company_name(name)
      return nil if name.blank?

      normalized = name.strip

      # Remove common company suffixes (case-insensitive)
      # e.g., "Koinly Inc" -> "Koinly", "Acme Corp." -> "Acme"
      suffixes = [
        /\s+inc\.?$/i,
        /\s+llc\.?$/i,
        /\s+corp\.?$/i,
        /\s+corporation$/i,
        /\s+ltd\.?$/i,
        /\s+limited$/i,
        /\s+co\.?$/i,
        /\s+company$/i,
        /\s+\.io$/i,
        /\s+\.com$/i,
        /\s+\.net$/i,
        /\s+\.org$/i
      ]

      suffixes.each do |suffix|
        normalized = normalized.gsub(suffix, "")
      end

      normalized.strip.titleize
    end

    # Checks if two company names are similar enough to be the same company
    #
    # @param [String] name1 First company name
    # @param [String] name2 Second company name
    # @return [Boolean] True if names are similar
    def names_similar?(name1, name2)
      return false if name1.blank? || name2.blank?

      # Exact match after normalization
      return true if name1.downcase == name2.downcase

      # Check if one name contains the other (for cases like "Koinly" vs "Koinly Inc")
      name1_down = name1.downcase
      name2_down = name2.downcase

      return true if name1_down.include?(name2_down) || name2_down.include?(name1_down)

      # Check Levenshtein distance for typos (max 2 character difference for short names)
      # This handles cases like "Koinly" vs "Koinley"
      distance = levenshtein_distance(name1_down, name2_down)
      max_distance = [ name1.length, name2.length ].min / 3 # Allow ~33% difference
      distance <= [ max_distance, 2 ].max
    end

    # Finds a similar company using fuzzy matching
    #
    # @param [String] normalized_name The normalized company name
    # @return [Company, nil] Similar company or nil
    def find_similar_company(normalized_name)
      return nil if normalized_name.blank?

      # Get all companies and check for similarity
      # This is not the most efficient, but company counts are typically small
      Company.find_each do |company|
        existing_normalized = normalize_company_name(company.name)
        return company if names_similar?(normalized_name, existing_normalized)
      end

      nil
    end

    # Calculates Levenshtein distance between two strings
    #
    # @param [String] str1 First string
    # @param [String] str2 Second string
    # @return [Integer] Distance
    def levenshtein_distance(str1, str2)
      m, n = str1.length, str2.length
      return n if m == 0
      return m if n == 0

      d = Array.new(m + 1) { Array.new(n + 1) }

      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }

      (1..n).each do |j|
        (1..m).each do |i|
          d[i][j] = if str1[i - 1] == str2[j - 1]
            d[i - 1][j - 1]
          else
            [ d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + 1 ].min
          end
        end
      end

      d[m][n]
    end

    # Extracts normalized domain from URL
    #
    # @param [String, nil] url The URL
    # @return [String, nil] Normalized domain or nil
    def extract_domain_from_url(url)
      return nil if url.blank?

      begin
        uri = URI.parse(url)
        domain = uri.host
        return nil unless domain

        # Normalize domain: remove www, convert to lowercase
        domain = domain.downcase
        domain = domain.sub(/^www\./, "")
        domain
      rescue
        nil
      end
    end

    # Checks if two domains match (handles www and subdomain variations)
    #
    # @param [String] domain1 First domain
    # @param [String] domain2 Second domain
    # @return [Boolean] True if domains match
    def domains_match?(domain1, domain2)
      return false if domain1.blank? || domain2.blank?

      # Normalize both domains
      norm1 = normalize_domain(domain1)
      norm2 = normalize_domain(domain2)

      # Exact match
      return true if norm1 == norm2

      # Check if one is a subdomain of the other
      # e.g., "careers.koinly.io" matches "koinly.io"
      norm1_parts = norm1.split(".")
      norm2_parts = norm2.split(".")

      # Check if one domain ends with the other (subdomain case)
      return true if norm1.end_with?(".#{norm2}") || norm2.end_with?(".#{norm1}")

      # Check base domain match (last 2 parts)
      # e.g., "careers.koinly.io" and "www.koinly.io" both have base "koinly.io"
      if norm1_parts.length >= 2 && norm2_parts.length >= 2
        base1 = norm1_parts[-2..-1].join(".")
        base2 = norm2_parts[-2..-1].join(".")
        return true if base1 == base2
      end

      false
    end

    # Normalizes a domain for comparison
    #
    # @param [String] domain The domain
    # @return [String] Normalized domain
    def normalize_domain(domain)
      return "" if domain.blank?

      # Remove protocol if present
      domain = domain.gsub(/^https?:\/\//, "")

      # Remove path if present
      domain = domain.split("/").first

      # Remove www prefix and convert to lowercase
      domain = domain.downcase
      domain = domain.sub(/^www\./, "")

      domain
    end

    # Finds a company by domain/website
    #
    # @param [String] domain The domain to search for
    # @return [Company, nil] Company with matching domain or nil
    def find_company_by_domain(domain)
      return nil if domain.blank?

      normalized_domain = normalize_domain(domain)

      # Search companies with websites
      Company.where.not(website: nil).find_each do |company|
        company_domain = extract_domain_from_url(company.website)
        return company if company_domain.present? && domains_match?(normalized_domain, company_domain)
      end

      nil
    end

    # Normalizes job role title for matching
    #
    # @param [String] title The job role title
    # @return [String] Normalized title
    def normalize_job_role_title(title)
      return nil if title.blank?

      title.strip
    end
  end
end
