# frozen_string_literal: true

module Scraping
  # Service for rate limiting requests per domain
  #
  # Uses Rails.cache to track request timestamps and enforce rate limits
  # to avoid overwhelming job board servers.
  #
  # @example
  #   limiter = Scraping::RateLimiterService.new("linkedin.com")
  #   if limiter.allowed?
  #     # Make request
  #     limiter.record_request!
  #   else
  #     sleep limiter.wait_time
  #   end
  class RateLimiterService
    # Initialize the rate limiter for a domain
    #
    # @param [String] domain The domain to rate limit
    def initialize(domain)
      @domain = domain
      @cache_key = "rate_limit:#{domain}"
      @cache = if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
        ActiveSupport::Cache::MemoryStore.new
      else
        Rails.cache
      end
    end

    # Checks if a request to this domain is allowed
    #
    # @return [Boolean] True if request can be made now
    def allowed?
      last_request_time = cache.read(@cache_key)
      return true if last_request_time.nil?

      time_since_last = Time.current - last_request_time
      time_since_last >= rate_limit_seconds
    end

    # Records a request timestamp for this domain
    #
    # @return [Boolean] True if successfully recorded
    def record_request!
      cache.write(@cache_key, Time.current, expires_in: 1.hour)
    end

    # Returns the wait time before next request is allowed
    #
    # @return [Float] Seconds to wait, 0 if can request now
    def wait_time
      return 0.0 if allowed?

      last_request_time = cache.read(@cache_key)
      return 0.0 if last_request_time.nil?

      time_since_last = Time.current - last_request_time
      remaining = rate_limit_seconds - time_since_last
      [ remaining, 0.0 ].max
    end

    # Blocks until the domain is ready for another request
    #
    # @return [void]
    def wait_if_needed!
      wait_seconds = wait_time
      sleep(wait_seconds) if wait_seconds > 0
    end

    private

    def cache
      @cache
    end

    # Returns the rate limit in seconds for this domain
    #
    # @return [Integer] Seconds between requests
    def rate_limit_seconds
      @rate_limit_seconds ||= load_rate_limit_config
    end

    # Loads rate limit from configuration
    #
    # @return [Integer] Seconds between requests
    def load_rate_limit_config
      config = YAML.load_file(Rails.root.join("config/rate_limits.yml"))

      # Try exact domain match first
      domain_limits = config["domains"] || {}
      return domain_limits[@domain] if domain_limits.key?(@domain)

      # Return default
      config["default"] || 5
    rescue => e
      Rails.logger.error("Failed to load rate limit config: #{e.message}")
      5 # Safe default
    end
  end
end
