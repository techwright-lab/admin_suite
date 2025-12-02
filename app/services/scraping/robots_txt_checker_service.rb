# frozen_string_literal: true

module Scraping
  # Service for checking robots.txt compliance
  #
  # Fetches and caches robots.txt files, then checks if a URL is allowed
  # to be scraped according to the robots.txt rules.
  #
  # @example
  #   checker = Scraping::RobotsTxtCheckerService.new("https://example.com/jobs/123")
  #   if checker.allowed?
  #     # Proceed with scraping
  #   end
  class RobotsTxtCheckerService
    USER_AGENT = "GleaniaBot/1.0"

    # Initialize the robots.txt checker for a URL
    #
    # @param [String] url The URL to check
    def initialize(url)
      @url = url
      @uri = URI.parse(url)
      @domain = @uri.host
    end

    # Checks if scraping this URL is allowed per robots.txt
    #
    # @return [Boolean] True if allowed or if robots.txt doesn't exist
    def allowed?
      return true unless @domain # Can't check without domain

      begin
        # The robots gem automatically fetches robots.txt for the domain
        parser = Robots.new(USER_AGENT)
        parser.allowed?(@url)
      rescue => e
        Rails.logger.warn("Failed to check robots.txt for #{@domain}: #{e.message}")
        true # On error, allow by default to not block functionality
      end
    end

    # Returns the crawl delay specified in robots.txt
    #
    # @return [Integer, nil] Delay in seconds or nil if not specified
    def crawl_delay
      robots_txt_content = fetch_robots_txt
      return nil if robots_txt_content.nil?

      # Parse crawl-delay directive
      match = robots_txt_content.match(/Crawl-delay:\s*(\d+)/i)
      match ? match[1].to_i : nil
    rescue => e
      Rails.logger.warn("Failed to get crawl delay for #{@domain}: #{e.message}")
      nil
    end

    private

    # Fetches robots.txt content for the domain
    #
    # @return [String, nil] robots.txt content or nil if not found
    def fetch_robots_txt
      cache_key = "robots_txt:#{@domain}"
      
      Rails.cache.fetch(cache_key, expires_in: 24.hours) do
        fetch_robots_txt_from_server
      end
    end

    # Fetches robots.txt from the server
    #
    # @return [String, nil] robots.txt content or nil
    def fetch_robots_txt_from_server
      robots_url = "#{@uri.scheme}://#{@domain}/robots.txt"
      
      response = HTTParty.get(
        robots_url,
        headers: {
          "User-Agent" => USER_AGENT
        },
        timeout: 10,
        follow_redirects: true
      )

      if response.success?
        Rails.logger.info("Fetched robots.txt for #{@domain}")
        response.body
      else
        Rails.logger.info("No robots.txt found for #{@domain} (#{response.code})")
        nil
      end
    rescue => e
      Rails.logger.warn("Failed to fetch robots.txt for #{@domain}: #{e.message}")
      nil
    end
  end
end

