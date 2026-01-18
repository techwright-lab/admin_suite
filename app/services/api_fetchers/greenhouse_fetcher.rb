# frozen_string_literal: true

require "cgi"

module ApiFetchers
  # Greenhouse API fetcher for job listings
  #
  # Uses Greenhouse's public job board API to fetch job listing data.
  # API docs: https://developers.greenhouse.io/job-board.html
  class GreenhouseFetcher < BaseFetcher
    BASE_URL = "https://boards-api.greenhouse.io/v1/boards"

    # Fetches job listing from Greenhouse API
    #
    # @param [String] url The job listing URL
    # @param [String] job_id The Greenhouse job ID
    # @param [String] company_slug The company board token/slug
    # @return [Hash] Standardized job data
    def fetch(url:, job_id: nil, company_slug: nil)
      return nil unless Setting.greenhouse_enabled?

      # If we don't have required params, try to extract from URL
      company_slug ||= extract_company_from_url(url)
      job_id ||= extract_job_id_from_url(url)

      raise ArgumentError, "Cannot fetch without company slug" unless company_slug
      raise ArgumentError, "Cannot fetch without job ID" unless job_id

      log_event("api_extraction_started", {
        board_type: "greenhouse",
        company_slug: company_slug,
        job_id: job_id,
        url: url
      })

      api_url = "#{BASE_URL}/#{company_slug}/jobs/#{job_id}"
      response = make_request(api_url)

      if response.success?
        result = parse_greenhouse_response(response.parsed_response)
        log_event("api_extraction_succeeded", {
          board_type: "greenhouse",
          confidence: result[:confidence]
        })
        result
      else
        log_event("api_extraction_failed", {
          board_type: "greenhouse",
          error: "API request failed: #{response.code}",
          http_status: response.code
        })
        { error: "API request failed: #{response.code}", confidence: 0.0 }
      end
    rescue => e
      log_error("Greenhouse API fetch failed", e)
      notify_error(
        e,
        context: "greenhouse_api_fetch",
        severity: "error",
        url: url,
        company_slug: company_slug,
        job_id: job_id
      )
      { error: e.message, confidence: 0.0 }
    end

    private

    # Parses Greenhouse API response to our standard format
    #
    # @param [Hash] data The Greenhouse API response
    # @return [Hash] Standardized job data
    def parse_greenhouse_response(data)
      location_name = data.dig("location", "name")
      content_html = decode_html(data["content"])

      # Determine remote type from location
      remote_type = if location_name&.downcase&.include?("remote")
        "remote"
      elsif location_name&.downcase&.include?("hybrid")
        "hybrid"
      else
        "on_site"
      end

      normalize_response(
        title: data["title"],
        description: content_html,
        requirements: extract_section(content_html, "requirements"),
        responsibilities: extract_section(content_html, "responsibilities"),
        location: location_name,
        remote_type: remote_type,
        salary_min: nil, # Greenhouse doesn't always expose salary in public API
        salary_max: nil,
        salary_currency: "USD",
        custom_sections: build_custom_sections(data)
      ).merge(
        company: data["company_name"]
      )
    end

    # Strips HTML tags from content
    #
    # @param [String] html HTML content
    # @return [String] Plain text
    def strip_html(html)
      return nil if html.blank?

      Nokogiri::HTML.fragment(html.to_s).text.to_s.gsub(/\s+/, " ").strip
    end

    # Extracts a specific section from job content
    #
    # @param [String] content The full job content
    # @param [String] section_name The section to extract
    # @return [String, nil] Extracted section or nil
    def extract_section(content, section_name)
      return nil if content.blank?

      # Try to find section by common headers
      patterns = [
        /<h[23][^>]*>#{section_name}<\/h[23]>(.*?)(?:<h[23]|$)/mi,
        /<strong>#{section_name}<\/strong>(.*?)(?:<strong>|$)/mi
      ]

      patterns.each do |pattern|
        match = content.match(pattern)
        return strip_html(match[1]) if match
      end

      nil
    end

    def decode_html(text)
      return "" if text.blank?

      CGI.unescapeHTML(text.to_s)
    rescue
      text.to_s
    end

    # Builds custom sections from Greenhouse data
    #
    # @param [Hash] data The Greenhouse response
    # @return [Hash] Custom sections
    def build_custom_sections(data)
      sections = {}

      if data["departments"]&.any?
        sections["departments"] = data["departments"].map { |d| d["name"] }
      end

      if data["offices"]&.any?
        sections["offices"] = data["offices"].map { |o| o["name"] }
      end

      sections["updated_at"] = data["updated_at"] if data["updated_at"]
      sections["absolute_url"] = data["absolute_url"] if data["absolute_url"]

      sections
    end

    # Extracts company slug from URL
    #
    # @param [String] url The job listing URL
    # @return [String, nil] Company slug
    def extract_company_from_url(url)
      match = url.match(%r{boards\.greenhouse\.io/([^/]+)})
      match ? match[1] : nil
    end

    # Extracts job ID from URL
    #
    # @param [String] url The job listing URL
    # @return [String, nil] Job ID
    def extract_job_id_from_url(url)
      match = url.match(%r{/jobs?/(\d+)}) || url.match(/gh_jid=([^&]+)/)
      match ? match[1] : nil
    end
  end
end
