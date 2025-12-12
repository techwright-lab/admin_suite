# frozen_string_literal: true

module ApiFetchers
  # Lever API fetcher for job listings
  #
  # Uses Lever's public postings API to fetch job listing data.
  # API docs: https://github.com/lever/postings-api
  class LeverFetcher < BaseFetcher
    BASE_URL = "https://api.lever.co/v0/postings"

    # Fetches job listing from Lever API
    #
    # @param [String] url The job listing URL
    # @param [String] job_id The Lever posting ID
    # @param [String] company_slug The company identifier
    # @return [Hash] Standardized job data
    def fetch(url:, job_id: nil, company_slug: nil)
      return nil unless Setting.lever_enabled?

      # If we don't have required params, try to extract from URL
      company_slug ||= extract_company_from_url(url)
      job_id ||= extract_job_id_from_url(url)

      raise ArgumentError, "Cannot fetch without company slug" unless company_slug

      log_event("api_extraction_started", {
        board_type: "lever",
        company_slug: company_slug,
        job_id: job_id,
        url: url
      })

      api_url = if job_id
        "#{BASE_URL}/#{company_slug}/#{job_id}"
      else
        # Fetch all postings and find by URL matching
        "#{BASE_URL}/#{company_slug}"
      end

      response = make_request(api_url)

      if response.success?
        data = response.parsed_response

        result = if job_id
          parse_lever_response(data)
        else
          # Find matching posting from list
          posting = data.find { |p| p["hostedUrl"] == url }
          posting ? parse_lever_response(posting) : { error: "Job not found", confidence: 0.0 }
        end

        if result[:error]
          log_event("api_extraction_failed", {
            board_type: "lever",
            error: result[:error]
          })
        else
          log_event("api_extraction_succeeded", {
            board_type: "lever",
            confidence: result[:confidence]
          })
        end

        result
      else
        log_event("api_extraction_failed", {
          board_type: "lever",
          error: "API request failed: #{response.code}",
          http_status: response.code
        })
        { error: "API request failed: #{response.code}", confidence: 0.0 }
      end
    rescue => e
      log_error("Lever API fetch failed", e)

      # Notify exception with API fetch context
      ExceptionNotifier.notify(e, {
        context: "lever_api_fetch",
        severity: "error",
        url: url,
        company_slug: company_slug,
        job_id: job_id
      })

      { error: e.message, confidence: 0.0 }
    end

    private

    # Parses Lever API response to our standard format
    #
    # @param [Hash] data The Lever API response
    # @return [Hash] Standardized job data
    def parse_lever_response(data)
      location = data.dig("categories", "location") || data.dig("location")

      # Determine remote type
      remote_type = if data["workplaceType"] == "remote"
        "remote"
      elsif data["workplaceType"] == "hybrid"
        "hybrid"
      else
        "on_site"
      end

      # Combine description sections
      description = [
        data["description"],
        data["descriptionPlain"]
      ].compact.first

      normalize_response(
        title: data["text"],
        description: description,
        requirements: extract_lists(data["lists"], [ "requirements", "qualifications" ]),
        responsibilities: extract_lists(data["lists"], [ "responsibilities", "role" ]),
        location: location,
        remote_type: remote_type,
        salary_min: nil, # Lever doesn't always expose salary in public API
        salary_max: nil,
        salary_currency: "USD",
        custom_sections: build_custom_sections(data)
      )
    end

    # Extracts content from lists by matching keys
    #
    # @param [Array] lists The lists array from Lever
    # @param [Array] keys Keys to match
    # @return [String, nil] Combined list content
    def extract_lists(lists, keys)
      return nil unless lists&.any?

      matching = lists.select { |list|
        list_text = list["text"].to_s.downcase
        keys.any? { |key| list_text.include?(key) }
      }

      return nil if matching.empty?

      matching.map { |list|
        content = list["content"]
        # Clean up HTML if present
        content.is_a?(String) ? content.gsub(/<[^>]+>/, "\n").strip : content
      }.join("\n\n")
    end

    # Builds custom sections from Lever data
    #
    # @param [Hash] data The Lever response
    # @return [Hash] Custom sections
    def build_custom_sections(data)
      sections = {}

      if data["categories"]
        sections["team"] = data["categories"]["team"]
        sections["department"] = data["categories"]["department"]
        sections["commitment"] = data["categories"]["commitment"]
      end

      sections["apply_url"] = data["applyUrl"] if data["applyUrl"]
      sections["hosted_url"] = data["hostedUrl"] if data["hostedUrl"]
      sections["created_at"] = data["createdAt"] if data["createdAt"]

      # Include additional lists that we didn't categorize
      if data["lists"]&.any?
        other_lists = data["lists"].reject { |list|
          text = list["text"].to_s.downcase
          text.include?("requirement") || text.include?("responsibilit") ||
          text.include?("qualif") || text.include?("role")
        }

        sections["additional_info"] = other_lists.map { |list|
          { "title" => list["text"], "content" => list["content"] }
        } if other_lists.any?
      end

      sections
    end

    # Extracts company slug from URL
    #
    # @param [String] url The job listing URL
    # @return [String, nil] Company slug
    def extract_company_from_url(url)
      match = url.match(%r{jobs\.lever\.co/([^/]+)})
      match ? match[1] : nil
    end

    # Extracts job ID from URL
    #
    # @param [String] url The job listing URL
    # @return [String, nil] Job ID
    def extract_job_id_from_url(url)
      match = url.match(%r{jobs\.lever\.co/[^/]+/([^/\?]+)})
      match ? match[1] : nil
    end
  end
end
