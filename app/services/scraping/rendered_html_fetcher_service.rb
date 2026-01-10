# frozen_string_literal: true

require "selenium-webdriver"
require "timeout"

module Scraping
  # Service for fetching JS-rendered HTML using a headless browser (Selenium)
  #
  # Intended as a fallback when static HTTP fetch returns a shell page and the
  # job content is populated client-side via JavaScript.
  #
  # Notes:
  # - This service is expensive; it should be used selectively (heuristics + caching).
  # - It returns full page HTML and also provides cleaned_html using Nokogiri cleaner.
  # - Wrapped with Ruby Timeout to prevent indefinite hangs from Selenium.
  class RenderedHtmlFetcherService
    DEFAULT_TIMEOUT_SECONDS = 30
    DEFAULT_WAIT_SECONDS = 10
    # Overall timeout for the entire operation (page load + wait + processing)
    # This is a hard limit to prevent indefinite hangs
    HARD_TIMEOUT_SECONDS = 90
    MAX_HTML_BYTES = 5.megabytes
    MAX_IFRAMES_TO_CHECK = 5

    # A realistic UA (some job boards degrade bot UAs).
    REALISTIC_UA =
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " \
      "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"

    # Best-effort selectors for “job content is present”.
    JOB_CONTENT_SELECTORS = [
      "[data-testid*='job']",
      "[data-testid*='description']",
      "[data-testid*='posting']",
      "[class*='job-description']",
      "[class*='jobDescription']",
      "[class*='job-details']",
      "[class*='jobDetails']",
      "[id*='job-description']",
      "[id*='jobDescription']",
      "main"
    ].freeze

    attr_reader :job_listing, :scraping_attempt, :url

    # @param job_listing [JobListing]
    # @param scraping_attempt [ScrapingAttempt, nil]
    # @param timeout [Integer] Overall page-load timeout
    # @param wait [Integer] Extra wait for content to settle
    def initialize(job_listing, scraping_attempt: nil, timeout: DEFAULT_TIMEOUT_SECONDS, wait: DEFAULT_WAIT_SECONDS)
      @job_listing = job_listing
      @scraping_attempt = scraping_attempt
      @url = job_listing.url
      @timeout = timeout
      @wait = wait
    end

    # Fetches rendered HTML using Selenium headless Chrome
    #
    # Wrapped with a hard timeout to prevent indefinite hangs from Selenium/network issues.
    #
    # @return [Hash] Result with :success, :html_content, :cleaned_html, :http_status, :error, :cached_data
    def call
      return error_result("URL is required") if url.blank?
      return error_result("JS rendering disabled") unless Setting.js_rendering_enabled?

      # Wrap entire operation in a timeout to prevent indefinite hangs
      Timeout.timeout(HARD_TIMEOUT_SECONDS, RenderedFetchTimeoutError) do
        perform_fetch
      end
    rescue RenderedFetchTimeoutError => e
      Rails.logger.error("Rendered fetch hard timeout after #{HARD_TIMEOUT_SECONDS}s for #{url}")
      ExceptionNotifier.notify(e, {
        context: "rendered_html_fetch_timeout",
        severity: "warning",
        url: url,
        job_listing_id: job_listing.id,
        scraping_attempt_id: scraping_attempt&.id,
        timeout_seconds: HARD_TIMEOUT_SECONDS
      })
      error_result("Rendered fetch timed out after #{HARD_TIMEOUT_SECONDS} seconds")
    rescue Selenium::WebDriver::Error::WebDriverError => e
      ExceptionNotifier.notify(e, {
        context: "rendered_html_fetch",
        severity: "error",
        url: url,
        job_listing_id: job_listing.id,
        scraping_attempt_id: scraping_attempt&.id
      })
      error_result("Rendered fetch failed: #{e.message}")
    rescue StandardError => e
      ExceptionNotifier.notify(e, {
        context: "rendered_html_fetch",
        severity: "error",
        url: url,
        job_listing_id: job_listing.id,
        scraping_attempt_id: scraping_attempt&.id
      })
      error_result("Rendered fetch failed: #{e.message}")
    end

    # Custom error for hard timeout
    class RenderedFetchTimeoutError < StandardError; end

    private

    # Performs the actual fetch operation (separated for timeout wrapping)
    def perform_fetch
      driver = nil
      begin
        driver = build_driver
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        driver.navigate.to(url)

        # Wait for document readiness
        wait_until(driver, @timeout) { driver.execute_script("return document.readyState") == "complete" }

        selector_probe = wait_for_job_content(driver)

        # Best-effort settle time for SPAs (bounded)
        sleep(@wait) if @wait.positive?

        html = driver.page_source.to_s
        if html.bytesize > MAX_HTML_BYTES
          return error_result("Rendered HTML too large (#{html.bytesize} bytes)")
        end

        # Use board-specific cleaner if available
        cleaner = Scraping::HtmlCleaners::CleanerFactory.cleaner_for_url(url)
        cleaned_html = cleaner.clean(html)

        iframe_result = selector_probe[:iframe_best_candidate]
        if iframe_result.present?
          # Prefer iframe HTML if it yields more extracted text
          iframe_cleaned = cleaner.clean(iframe_result[:iframe_html].to_s)
          if extracted_text_length(iframe_cleaned) > extracted_text_length(cleaned_html)
            html = iframe_result[:iframe_html].to_s
            cleaned_html = iframe_cleaned
            selector_probe[:iframe_used] = true
          end
        end

        cleaned_text_length = extracted_text_length(cleaned_html)

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

        cached_data = ScrapedJobListingData.create_with_html(
          url: url,
          html_content: html,
          job_listing: job_listing,
          scraping_attempt: scraping_attempt,
          http_status: nil,
          metadata: {
            fetched_via: "selenium",
            rendered: true,
            duration_ms: duration_ms,
            selector_found: selector_probe[:selector_found],
            found_selectors: selector_probe[:found_selectors],
            selector_wait_ms: selector_probe[:selector_wait_ms],
            iframe_used: selector_probe[:iframe_used],
            cleaned_text_length: cleaned_text_length
          }
        )

        {
          success: true,
          html_content: html,
          cleaned_html: cleaned_html,
          cached_data: cached_data,
          from_cache: false,
          http_status: nil,
          duration_ms: duration_ms,
          selector_found: selector_probe[:selector_found],
          found_selectors: selector_probe[:found_selectors],
          selector_wait_ms: selector_probe[:selector_wait_ms],
          iframe_used: selector_probe[:iframe_used],
          cleaned_text_length: cleaned_text_length
        }
      ensure
        driver&.quit
      end
    end

    def build_driver
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--headless=new")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
      options.add_argument("--window-size=1280,1024")
      options.add_argument("--lang=en-US")

      # Prefer a realistic UA to avoid degraded “bot” experiences.
      options.add_argument("--user-agent=#{REALISTIC_UA}")

      # Support remote Selenium Grid via environment variables (for scaling)
      if selenium_remote_url.present?
        driver = Selenium::WebDriver.for(:remote, url: selenium_remote_url, options: options)
      else
        # Local ChromeDriver (will auto-download via webdriver gem if needed)
        driver = Selenium::WebDriver.for(:chrome, options: options)
      end

      driver.manage.timeouts.page_load = @timeout
      driver
    end

    # Returns remote Selenium Grid URL if configured, nil otherwise
    #
    # @return [String, nil]
    def selenium_remote_url
      return nil unless ENV["SELENIUM_REMOTE_URL"].present?

      ENV["SELENIUM_REMOTE_URL"]
    end

    def wait_until(driver, seconds)
      wait = Selenium::WebDriver::Wait.new(timeout: seconds)
      wait.until { yield }
    rescue Selenium::WebDriver::Error::TimeoutError
      # Continue best-effort if readiness never reports complete
      nil
    end

    # Waits (best-effort) until job content appears in the DOM.
    #
    # @param driver [Selenium::WebDriver]
    # @return [Hash]
    def wait_for_job_content(driver)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      found_selectors = []
      selector_found = false
      iframe_best_candidate = nil
      iframe_used = false

      selector_found, found_selectors = wait_for_any_selector(driver, JOB_CONTENT_SELECTORS, timeout: [ @timeout, 15 ].min)

      # If not found, check a small number of iframes for content (best-effort).
      if !selector_found
        iframes = driver.find_elements(css: "iframe").first(MAX_IFRAMES_TO_CHECK)
        iframes.each do |iframe|
          begin
            driver.switch_to.frame(iframe)
            iframe_found, iframe_selectors = wait_for_any_selector(driver, JOB_CONTENT_SELECTORS, timeout: 6)
            if iframe_found
              iframe_html = driver.page_source.to_s
              iframe_best_candidate = { iframe_html: iframe_html, found_selectors: iframe_selectors }
              break
            end
          rescue Selenium::WebDriver::Error::WebDriverError
            nil
          ensure
            begin
              driver.switch_to.default_content
            rescue Selenium::WebDriver::Error::WebDriverError
              nil
            end
          end
        end
      end

      selector_wait_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

      {
        selector_found: selector_found,
        found_selectors: found_selectors.first(10),
        selector_wait_ms: selector_wait_ms,
        iframe_used: iframe_used,
        iframe_best_candidate: iframe_best_candidate
      }
    rescue => e
      Rails.logger.debug("RenderedHtmlFetcherService wait_for_job_content error: #{e.message}")
      { selector_found: false, found_selectors: [], selector_wait_ms: nil, iframe_used: false, iframe_best_candidate: nil }
    end

    def wait_for_any_selector(driver, selectors, timeout:)
      found = []
      wait_until(driver, timeout) do
        found = selectors.select { |sel| dom_has_selector?(driver, sel) }
        found.any?
      end
      [ found.any?, found ]
    rescue
      [ false, [] ]
    end

    def dom_has_selector?(driver, selector)
      driver.execute_script("return !!document.querySelector(arguments[0])", selector) == true
    rescue Selenium::WebDriver::Error::JavascriptError
      false
    end

    # Rough “how much text do we have?” metric for deciding if rendered fetch worked.
    #
    # @param html [String]
    # @return [Integer]
    def extracted_text_length(html)
      Nokogiri::HTML(html.to_s).text.to_s.strip.length
    rescue
      0
    end

    def error_result(message)
      {
        success: false,
        error: message,
        html_content: nil,
        cleaned_html: nil,
        cached_data: nil,
        from_cache: false
      }
    end
  end
end
