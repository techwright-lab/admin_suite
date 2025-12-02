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
    def initialize(job_listing: nil, scraping_attempt: nil)
      @job_listing = job_listing
      @scraping_attempt = scraping_attempt
      @url = job_listing&.url
      @field_results = {}
      @selectors_tried = {}
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
        duration_ms: @duration_ms,
        field_results: @field_results,
        selectors_tried: @selectors_tried,
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
      # Try salary-specific selectors
      salary_text = nil
      FIELD_SELECTORS[:salary].each do |selector|
        @selectors_tried[:salary] ||= []
        @selectors_tried[:salary] << selector
        element = doc.css(selector).first
        if element
          salary_text = element.text
          break
        end
      end

      # Fallback to searching entire text
      @selectors_tried[:salary] << "text_pattern_search" if salary_text.nil?
      salary_text ||= doc.text

      # Parse salary patterns
      patterns = [
        /\$?\s*(\d{1,3}(?:,\d{3})*(?:k|K)?)\s*[-–—]\s*\$?\s*(\d{1,3}(?:,\d{3})*(?:k|K)?)\s*([A-Z]{3})?/,
        /\$?\s*(\d{1,3}(?:,\d{3})*(?:k|K)?)\s+to\s+\$?\s*(\d{1,3}(?:,\d{3})*(?:k|K)?)\s*([A-Z]{3})?/,
        /\$?\s*(\d{1,3}(?:,\d{3})*(?:k|K)?)\s*\+/,
        /\$?\s*(\d{1,3}(?:,\d{3})*(?:k|K)?)/
      ]

      patterns.each do |pattern|
        match = salary_text.match(pattern)
        next unless match

        min_str = match[1]&.gsub(/[,\s]/, "")&.gsub(/k$/i, "000")
        max_str = match[2]&.gsub(/[,\s]/, "")&.gsub(/k$/i, "000")
        currency = match[3] || (salary_text.include?("$") ? "USD" : nil)

        min = min_str.to_f if min_str
        max = max_str.to_f if max_str

        return { min: min, max: max, currency: currency || "USD" } if min || max
      end

      {}
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
          name = element.text.strip
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
  end
end
