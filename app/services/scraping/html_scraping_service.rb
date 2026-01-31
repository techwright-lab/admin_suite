# frozen_string_literal: true

require "nokogiri"

module Scraping
  # Service for extracting structured job listing data from HTML using Nokogiri
  #
  # Extracts basic fields from HTML using CSS selectors and text analysis
  # to find common job board patterns. This is a fast, cheap extraction method
  # that runs before expensive API/AI extraction.
  #
  # @example
  #   extractor = Scraping::HtmlScrapingService.new
  #   data = extractor.extract(html_content, url)
  #   job_listing.update(data)
  class HtmlScrapingService
    include Concerns::Loggable

    # Field extraction configurations with selectors in priority order
    FIELD_SELECTORS = {
      title: [
        "h1.job-title",
        "[data-job-title]",
        "[class*='job-title']",
        "[id*='job-title']",
        "h1",
        ".title",
        "[class*='title']"
      ],
      location: [
        "[data-location]",
        "[class*='location']",
        "[id*='location']",
        "address",
        ".location",
        "[class*='address']"
      ],
      company_name: [
        "[data-company]",
        "[class*='company']",
        "[id*='company']",
        ".company",
        ".company-name",
        "[itemprop='name']"
      ],
      description: [
        "[data-description]",
        "[class*='description']",
        "[id*='description']",
        ".description",
        ".job-description",
        "main p",
        "article p",
        "[role='main'] p"
      ],
      about_company: [
        "[data-about]",
        "[id*='about']",
        "[class*='about']",
        ".about",
        ".about-us",
        ".company-about"
      ],
      company_culture: [
        "[data-culture]",
        "[id*='culture']",
        "[class*='culture']",
        "[id*='values']",
        "[class*='values']",
        "[id*='mission']",
        "[class*='mission']"
      ],
      salary: [
        "[data-salary]",
        "[class*='salary']",
        "[id*='salary']",
        ".salary",
        "[class*='compensation']"
      ]
    }.freeze

    # Initialize the HTML scraper
    #
    # @param [JobListing, nil] job_listing Optional job listing for logging context
    # @param [ScrapingAttempt, nil] scraping_attempt Optional scraping attempt for logging context
    def initialize(job_listing: nil, scraping_attempt: nil, fetch_mode: nil, board_type: nil, extractor_kind: "generic_html_scraping", run_context: "orchestrator")
      @job_listing = job_listing
      @scraping_attempt = scraping_attempt
      @url = job_listing&.url
      @field_results = {}
      @selectors_tried = {}
      @fetch_mode = fetch_mode
      @board_type = board_type
      @extractor_kind = extractor_kind
      @run_context = run_context
    end

    # Extracts structured data from HTML
    #
    # @param [String] html_content The HTML content
    # @param [String] url The job listing URL (for logging context)
    # @return [Hash] Extracted data hash
    def extract(html_content, url = nil)
      return {} if html_content.blank?

      @url ||= url
      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @html_size = html_content.bytesize
      @cleaned_html_size = Scraping::NokogiriHtmlCleanerService.new.clean(html_content).bytesize

      log_event("html_scraping_started")

      doc = Nokogiri::HTML(html_content)

      # Clean up cookie banners first
      remove_cookie_banners(doc)

      result = {
        title: extract_with_tracking(:title, doc) { extract_title(doc) },
        location: extract_with_tracking(:location, doc) { extract_location(doc) },
        remote_type: extract_with_tracking(:remote_type, doc) { extract_remote_type(doc) },
        salary_min: nil,
        salary_max: nil,
        salary_currency: nil,
        description: extract_with_tracking(:description, doc) { extract_description(doc) },
        company_name: extract_with_tracking(:company_name, doc) { extract_company_name(doc) },
        about_company: extract_with_tracking(:about_company, doc) { extract_about_company(doc) },
        company_culture: extract_with_tracking(:company_culture, doc) { extract_company_culture(doc) },
        job_role_title: nil
      }

      # Handle salary separately (multiple fields from one extraction)
      salary_data = extract_with_tracking(:salary, doc) { extract_salary_data(doc) }
      if salary_data.is_a?(Hash)
        result[:salary_min] = salary_data[:min]
        result[:salary_max] = salary_data[:max]
        result[:salary_currency] = salary_data[:currency]
      end

      # Job role title comes from title
      result[:job_role_title] = result[:title]

      # Remove nil values
      result.compact!

      # Calculate duration
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @duration_ms = ((end_time - @start_time) * 1000).round

      # Create the log record
      create_scraping_log(result)

      if result.any?
        log_event("html_scraping_succeeded", {
          fields_extracted: result.keys,
          extraction_rate: calculate_extraction_rate,
          duration_ms: @duration_ms,
          title: result[:title],
          location: result[:location]
        })
      else
        log_event("html_scraping_no_data_extracted", {
          duration_ms: @duration_ms,
          selectors_tried: @selectors_tried.keys
        })
      end

      result
    rescue => e
      log_error("HTML scraping failed", e)
      create_scraping_log({}, error: e)
      {}
    end

    private

    # Removes cookie banners and consent dialogs from the document
    #
    # @param [Nokogiri::HTML::Document] doc The parsed HTML
    def remove_cookie_banners(doc)
      doc.css("div[id*='cookie'], div[class*='cookie'], div[id*='consent'], div[class*='consent'], div[id*='gdpr'], div[class*='gdpr']").remove
    end

    # Wraps field extraction with tracking
    #
    # @param [Symbol] field_name The field being extracted
    # @param [Nokogiri::HTML::Document] doc The parsed HTML
    # @yield The extraction block
    # @return [Object] The extracted value
    def extract_with_tracking(field_name, doc)
      @selectors_tried[field_name] = []

      value = yield

      @field_results[field_name] = {
        "success" => value.present?,
        "value" => truncate_value(value),
        "selectors_tried" => @selectors_tried[field_name]
      }

      if value.present? && @selectors_tried[field_name].any?
        @field_results[field_name]["selector"] = @selectors_tried[field_name].last
      end

      value
    end

    # Truncates a value for storage
    #
    # @param [Object] value The value to truncate
    # @return [Object] Truncated value
    def truncate_value(value)
      case value
      when String
        value.length > 500 ? value[0...500] + "..." : value
      when Hash
        value.transform_values { |v| truncate_value(v) }
      else
        value
      end
    end

    # Calculates extraction rate
    #
    # @return [Float] Extraction rate between 0 and 1
    def calculate_extraction_rate
      return 0.0 if @field_results.empty?

      successful = @field_results.count { |_, v| v["success"] }
      successful.to_f / @field_results.count
    end

    # Creates the HtmlScrapingLog record
    #
    # @param [Hash] result The extraction result
    # @param [Exception, nil] error Optional error
    def create_scraping_log(result, error: nil)
      return unless @scraping_attempt

      domain = begin
        URI.parse(@url).host
      rescue
        "unknown"
      end

      HtmlScrapingLog.create!(
        scraping_attempt: @scraping_attempt,
        job_listing: @job_listing,
        url: @url,
        domain: domain,
        html_size: @html_size,
        cleaned_html_size: @cleaned_html_size,
        duration_ms: @duration_ms,
        field_results: @field_results,
        selectors_tried: @selectors_tried,
        fetch_mode: @fetch_mode,
        board_type: @board_type,
        extractor_kind: @extractor_kind,
        run_context: @run_context,
        error_type: error&.class&.name,
        error_message: error&.message
      )
    rescue => e
      Rails.logger.error("Failed to create HtmlScrapingLog: #{e.message}")
    end

    # Extracts job title
    #
    # @param [Nokogiri::HTML::Document] doc The parsed HTML
    # @return [String, nil] Job title
    def extract_title(doc)
      # Common cookie banner text patterns to skip
      cookie_patterns = [
        /select which cookies/i,
        /accept.*cookies/i,
        /cookie.*preferences/i,
        /manage.*cookies/i,
        /cookie.*consent/i
      ]

      FIELD_SELECTORS[:title].each do |selector|
        @selectors_tried[:title] << selector
        element = doc.css(selector).first
        if element
          title = element.text.strip
          # Skip if it looks like cookie banner text
          next if cookie_patterns.any? { |pattern| title.match?(pattern) }
          return title if title.present? && title.length < 200 && title.length > 3
        end
      end

      nil
    end

    # Extracts location
    #
    # @param [Nokogiri::HTML::Document] doc The parsed HTML
    # @return [String, nil] Location
    def extract_location(doc)
      FIELD_SELECTORS[:location].each do |selector|
        @selectors_tried[:location] << selector
        element = doc.css(selector).first
        if element
          location = element.text.strip
          return location if location.present? && location.length < 200
        end
      end

      # Try to find location in text content
      @selectors_tried[:location] << "text_pattern_search"
      text = doc.text
      location_patterns = [
        /(?:Location|Location:)\s*([A-Z][^,\n]{2,50}(?:,\s*[A-Z]{2})?)/i,
        /([A-Z][^,\n]{2,50},\s*[A-Z]{2})/,
        /(Remote|Hybrid|On-site|Onsite)/i
      ]

      location_patterns.each do |pattern|
        match = text.match(pattern)
        return match[1].strip if match && match[1]
      end

      nil
    end

    # Infers remote type from content
    #
    # @param [Nokogiri::HTML::Document] doc The parsed HTML
    # @return [Symbol, nil] :remote, :hybrid, or :on_site
    def extract_remote_type(doc)
      @selectors_tried[:remote_type] ||= []
      @selectors_tried[:remote_type] << "text_pattern_search"

      text = doc.text.downcase

      # Check for explicit remote indicators
      if text.match?(/\b(remote|work from home|wfh|distributed|anywhere)\b/i)
        return :remote
      end

      # Check for hybrid indicators
      if text.match?(/\b(hybrid|flexible|partially remote)\b/i)
        return :hybrid
      end

      # Check for on-site indicators
      if text.match?(/\b(on.?site|on.?premise|in.?office|in.?person)\b/i)
        return :on_site
      end

      nil
    end

    # Extracts salary information
    #
    # @param [Nokogiri::HTML::Document] doc The parsed HTML
    # @return [Hash] Salary data with :min, :max, :currency
    def extract_salary_data(doc)
      # First try salary-specific selectors (best signal).
      salary_text = nil
      salary_context = nil
      FIELD_SELECTORS[:salary].each do |selector|
        @selectors_tried[:salary] ||= []
        @selectors_tried[:salary] << selector
        element = doc.css(selector).first
        next unless element

        salary_text = element.text.to_s
        salary_context = salary_text
        break
      end

      # Conservative fallback: only scan lines that likely relate to compensation.
      if salary_text.nil?
        @selectors_tried[:salary] << "text_pattern_search"
        salary_text = compensation_candidate_text(doc.text.to_s)
        salary_context = salary_text
      end

      return {} if salary_text.blank?

      parsed = parse_salary_from_text(salary_text)
      return {} unless parsed

      normalized = Scraping::SalaryRangeValidator.normalize(
        min: parsed[:min],
        max: parsed[:max],
        currency: parsed[:currency],
        context_text: salary_context
      )

      return {} unless normalized[:valid]

      { min: normalized[:min], max: normalized[:max], currency: normalized[:currency] }
    end

    # Extracts only the lines most likely to contain compensation.
    #
    # This prevents false positives like "89 - 7" pulled from unrelated prose.
    #
    # @param text [String]
    # @return [String]
    def compensation_candidate_text(text)
      return "" if text.blank?

      lines = text.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
      return "" if lines.empty?

      needle = /\b(salary|compensation|pay|remuneration|total\s+comp|ote|base)\b|[$€£]|\b(usd|eur|gbp|pln|chf|cad|aud)\b/i
      picked = lines.select { |l| l.match?(needle) }
      picked.first(15).join("\n")
    end

    def parse_salary_from_text(text)
      return nil if text.blank?

      # Require some "money signal" in the text to avoid matching arbitrary numbers.
      money_signal = /\b(salary|compensation|pay|remuneration|total\s+comp|ote|base)\b|[$€£]|\b(usd|eur|gbp|pln|chf|cad|aud)\b/i
      return nil unless text.match?(money_signal)

      # Range patterns (support k and decimals).
      range_patterns = [
        /(?<cur>[$€£])?\s*(?<min>\d[\d\s,\.]*\d\s*[kK]?)\s*(?:-|–|—|\bto\b)\s*(?<cur2>[$€£])?\s*(?<max>\d[\d\s,\.]*\d\s*[kK]?)\s*(?<code>[A-Z]{3})?/i,
        /(?<min>\d[\d\s,\.]*\d\s*[kK]?)\s*(?<code>[A-Z]{3})\s*(?:-|–|—|\bto\b)\s*(?<max>\d[\d\s,\.]*\d\s*[kK]?)/i
      ]

      range_patterns.each do |re|
        m = text.match(re)
        next unless m

        currency = currency_from_match(m)
        return nil if currency.blank?

        return {
          min: m[:min],
          max: m[:max],
          currency: currency
        }
      end

      # Single "min+" pattern. We still require a currency signal.
      single_re = /(?<cur>[$€£])?\s*(?<min>\d[\d\s,\.]*\d\s*[kK]?)\s*\+\s*(?<code>[A-Z]{3})?/i
      m = text.match(single_re)
      return nil unless m

      currency = currency_from_match(m)
      return nil if currency.blank?

      {
        min: m[:min],
        max: nil,
        currency: currency
      }
    end

    def currency_from_match(match)
      code = match[:code].to_s.strip.upcase.presence
      return code if code.present?

      symbol = (match[:cur] || match[:cur2]).to_s.strip
      case symbol
      when "$" then "USD"
      when "€" then "EUR"
      when "£" then "GBP"
      else
        nil
      end
    end

    # Extracts job description summary
    #
    # @param [Nokogiri::HTML::Document] doc The parsed HTML
    # @return [String, nil] Description summary
    def extract_description(doc)
      FIELD_SELECTORS[:description].each do |selector|
        @selectors_tried[:description] << selector
        elements = doc.css(selector)
        next if elements.empty?

        # Get first paragraph or concatenate first few
        text = elements.first(3).map(&:text).join("\n\n").strip
        return text[0...2000] if text.present? # Limit to 2000 chars
      end

      nil
    end

    # Extracts company name
    #
    # @param [Nokogiri::HTML::Document] doc The parsed HTML
    # @return [String, nil] Company name
    def extract_company_name(doc)
      FIELD_SELECTORS[:company_name].each do |selector|
        @selectors_tried[:company_name] << selector
        element = doc.css(selector).first
        if element
          name = element["content"] || element["alt"] || element.text
          name = name.to_s.strip
          return name if name.present? && name.length < 100
        end
      end

      # Try meta tags
      @selectors_tried[:company_name] << "meta_tags"
      meta_company = doc.css("meta[property='og:site_name'], meta[name='company']").first
      if meta_company
        name = meta_company["content"] || meta_company["value"]
        return name.strip if name.present?
      end

      nil
    end

    def extract_about_company(doc)
      text = extract_block_from_selectors(doc, :about_company, max_chars: 2000)
      return text if text.present?

      extract_section_by_heading(doc, /about\s+(the\s+)?company|about\s+us|who\s+we\s+are/i, max_chars: 2000)
    end

    def extract_company_culture(doc)
      text = extract_block_from_selectors(doc, :company_culture, max_chars: 2000)
      return text if text.present?

      extract_section_by_heading(doc, /culture|values|mission|principles|how\s+we\s+work/i, max_chars: 2000)
    end

    def extract_block_from_selectors(doc, field, max_chars:)
      FIELD_SELECTORS[field].each do |selector|
        @selectors_tried[field] << selector
        element = doc.css(selector).first
        next unless element

        text = element.text.to_s.squish
        return text[0...max_chars] if text.present?
      end

      nil
    end

    def extract_section_by_heading(doc, heading_regex, max_chars:)
      headings = doc.css("h1, h2, h3, h4, strong, b")
      headings.each do |heading|
        next unless heading.text.to_s.squish.match?(heading_regex)

        # Collect siblings until next heading-like element
        chunks = []
        node = heading
        while (node = node.next_sibling)
          break if node.element? && node.name.to_s.match?(/\Ah[1-6]\z/i)
          next if node.text?

          text = node.text.to_s.squish
          next if text.blank?

          chunks << text
          break if chunks.join("\n\n").length >= max_chars
        end

        combined = chunks.join("\n\n").strip
        return combined[0...max_chars] if combined.present?
      end

      nil
    end
  end
end
