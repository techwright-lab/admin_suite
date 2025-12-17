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

        # Best-effort settle time for SPAs (bounded)
        sleep(@wait) if @wait.positive?

        html = driver.page_source.to_s
        if html.bytesize > MAX_HTML_BYTES
          return error_result("Rendered HTML too large (#{html.bytesize} bytes)")
        end

        # Use board-specific cleaner if available
        cleaner = Scraping::HtmlCleaners::CleanerFactory.cleaner_for_url(url)
        cleaned_html = cleaner.clean(html)

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
            duration_ms: duration_ms
          }
        )

        {
          success: true,
          html_content: html,
          cleaned_html: cleaned_html,
          cached_data: cached_data,
          from_cache: false,
          http_status: nil,
          duration_ms: duration_ms
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

      # Prefer a stable UA for consistent rendering
      options.add_argument("--user-agent=GleaniaBot/1.0 (+https://gleania.com/bot)")

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
