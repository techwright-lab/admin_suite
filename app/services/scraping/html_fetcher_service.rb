# frozen_string_literal: true

module Scraping
  # Service for idempotent HTML fetching with caching
  #
  # Fetches HTML content from URLs and caches it in ScrapedJobListingData
  # to avoid repeated network requests. Respects validity periods and
  # enables retries without re-fetching.
  #
  # @example
  #   fetcher = Scraping::HtmlFetcherService.new(job_listing, scraping_attempt)
  #   result = fetcher.call
  #   if result[:success]
  #     html_content = result[:html_content]
  #     cached_data = result[:cached_data]
  #   end
  class HtmlFetcherService
    include Concerns::Loggable

    attr_reader :job_listing, :scraping_attempt, :url

    # Initialize the HTML fetcher
    #
    # @param [JobListing] job_listing The job listing
    # @param [ScrapingAttempt, nil] scraping_attempt Optional scraping attempt
    def initialize(job_listing, scraping_attempt: nil)
      @job_listing = job_listing
      @scraping_attempt = scraping_attempt
      @url = job_listing.url
    end

    # Fetches HTML content (from cache or network)
    #
    # @return [Hash] Result hash with success status, html_content, and cached_data
    def call
      return error_result("URL is required") if @url.blank?

      log_event("html_fetch_started")

      # Check for valid cached HTML first
      cached_data = find_valid_cache

      if cached_data
        log_event("html_fetch_succeeded", {
          from_cache: true,
          valid_until: cached_data.valid_until.iso8601
        })
        return success_result(
          html_content: cached_data.html_content,
          cleaned_html: cached_data.cleaned_html,
          cached_data: cached_data,
          from_cache: true
        )
      end

      # No valid cache, fetch from network
      fetch_from_network
    end

    private

    # Finds valid cached HTML for the URL
    #
    # @return [ScrapedJobListingData, nil] Cached data or nil
    def find_valid_cache
      ScrapedJobListingData.find_valid_for_url(@url, job_listing: @job_listing)
    end

    # Fetches HTML from network and caches it
    #
    # @return [Hash] Result hash
    def fetch_from_network
      start_time = Time.current
      response = HTTParty.get(
        @url,
        headers: {
          "User-Agent" => "GleaniaBot/1.0 (+https://gleania.com/bot)",
          "Accept" => "text/html",
          "Accept-Language" => "en-US,en;q=0.9"
        },
        timeout: 30,
        open_timeout: 10,
        follow_redirects: true,
        max_redirects: 3
      )

      duration = Time.current - start_time

      if response.success?
        # Save to cache
        cached_data = save_to_cache(response, duration)

        log_event("html_fetch_succeeded", {
          from_cache: false,
          http_status: response.code,
          duration_seconds: duration
        })

        success_result(
          html_content: response.body,
          cleaned_html: cached_data.cleaned_html,
          cached_data: cached_data,
          from_cache: false,
          http_status: response.code
        )
      else
        log_event("html_fetch_failed", {
          error: "HTTP #{response.code}: Failed to fetch HTML",
          http_status: response.code
        })
        error_result("HTTP #{response.code}: Failed to fetch HTML", http_status: response.code)
      end
    rescue Timeout::Error => e
      log_error("HTML fetch timeout", e)
      error_result("Request timeout: #{e.message}")
    rescue => e
      log_error("HTML fetch failed", e)

      # Notify exception for HTML fetch failures
      ExceptionNotifier.notify(e, {
        context: "html_fetch",
        severity: "error",
        url: @url,
        job_listing_id: @job_listing.id
      })

      error_result("Failed to fetch HTML: #{e.message}")
    end

    # Saves HTML content to cache
    #
    # @param [HTTParty::Response] response The HTTP response
    # @param [Float] duration Fetch duration in seconds
    # @return [ScrapedJobListingData] The cached data
    def save_to_cache(response, duration)
      metadata = {
        fetched_at: Time.current.iso8601,
        fetched_via: "http",
        fetch_mode: "static",
        rendered: false,
        duration_seconds: duration,
        content_length: response.body.length,
        headers: response.headers.to_h.slice("content-type", "content-encoding", "last-modified")
      }

      # Use board-specific cleaner if available, otherwise fall back to generic
      cleaner = Scraping::HtmlCleaners::CleanerFactory.cleaner_for_url(@url)
      cleaned_html = cleaner.clean(response.body)

      ScrapedJobListingData.create_with_html(
        url: @url,
        html_content: response.body,
        job_listing: @job_listing,
        scraping_attempt: @scraping_attempt,
        http_status: response.code,
        metadata: metadata
      )
    end

    # Returns a success result hash
    #
    # @param [Hash] data Additional data
    # @return [Hash] Success result
    def success_result(data = {})
      {
        success: true,
        html_content: data[:html_content],
        cleaned_html: data[:cleaned_html],
        cached_data: data[:cached_data],
        from_cache: data[:from_cache] || false,
        http_status: data[:http_status]
      }
    end

    # Returns an error result hash
    #
    # @param [String] error_message The error message
    # @param [Hash] additional_data Additional error data
    # @return [Hash] Error result
    def error_result(error_message, additional_data = {})
      {
        success: false,
        error: error_message,
        html_content: nil,
        cached_data: nil,
        from_cache: false
      }.merge(additional_data)
    end
  end
end
