# frozen_string_literal: true

module Scraping
  # Service for tracking and limiting Anthropic API token usage
  #
  # Implements a rolling window rate limiter to ensure we don't exceed
  # Anthropic's 30,000 input tokens per minute limit.
  #
  # @example
  #   limiter = Scraping::AnthropicRateLimiterService.new
  #   if limiter.can_send_tokens?(estimated_tokens)
  #     # Make request
  #     limiter.record_tokens_used(actual_tokens)
  #   else
  #     wait_time = limiter.wait_time_for_tokens(estimated_tokens)
  #     sleep(wait_time)
  #   end
  class AnthropicRateLimiterService
    TOKEN_LIMIT_PER_MINUTE = 30_000
    WINDOW_SECONDS = 60
    CACHE_KEY = "anthropic_token_usage"
    CACHE_EXPIRATION = 2.minutes # Longer than window to handle edge cases

    # Checks if a request with estimated tokens can be sent
    #
    # @param [Integer] estimated_tokens Estimated token count for the request
    # @return [Boolean] True if request can be sent
    def can_send_tokens?(estimated_tokens)
      current_usage = total_usage_in_window
      (current_usage + estimated_tokens) <= TOKEN_LIMIT_PER_MINUTE
    end

    # Calculates wait time needed before sending tokens
    #
    # @param [Integer] estimated_tokens Estimated token count
    # @return [Float] Seconds to wait (0 if can send immediately)
    def wait_time_for_tokens(estimated_tokens)
      return 0.0 if can_send_tokens?(estimated_tokens)

      current_usage = total_usage_in_window
      tokens_needed = estimated_tokens
      tokens_available = TOKEN_LIMIT_PER_MINUTE - current_usage

      if tokens_available < tokens_needed
        # Need to wait for window to roll over
        oldest_timestamp = oldest_request_time
        return 0.0 if oldest_timestamp.nil?

        elapsed = Time.current - oldest_timestamp
        remaining = WINDOW_SECONDS - elapsed
        [ remaining.ceil, 0 ].max.to_f
      else
        0.0
      end
    end

    # Records token usage for a request
    #
    # @param [Integer] tokens Actual tokens used
    # @return [void]
    def record_tokens_used(tokens)
      return if tokens.nil? || tokens <= 0

      usage = current_usage_array
      usage << { timestamp: Time.current, tokens: tokens }

      # Clean up old entries (older than 1 minute)
      cleanup_old_entries(usage)

      # Store back to cache
      Rails.cache.write(CACHE_KEY, usage, expires_in: CACHE_EXPIRATION)
    end

    # Gets current total token usage in the rolling window
    #
    # @return [Integer] Total tokens used in last 60 seconds
    def total_usage_in_window
      usage = current_usage_array
      cleanup_old_entries(usage)

      usage.sum { |entry| entry[:tokens] }
    end

    private

    # Gets the current usage array from cache
    #
    # @return [Array<Hash>] Array of {timestamp, tokens} entries
    def current_usage_array
      Rails.cache.read(CACHE_KEY) || []
    end

    # Removes entries older than the window
    #
    # @param [Array<Hash>] usage The usage array (modified in place)
    # @return [void]
    def cleanup_old_entries(usage)
      cutoff = Time.current - WINDOW_SECONDS.seconds
      usage.reject! { |entry| entry[:timestamp] < cutoff }
    end

    # Gets the timestamp of the oldest request in the window
    #
    # @return [Time, nil] Oldest timestamp or nil
    def oldest_request_time
      usage = current_usage_array
      return nil if usage.empty?

      usage.map { |e| e[:timestamp] }.min
    end
  end
end
