# frozen_string_literal: true

module Scraping
  # Service for detecting job board type from URL
  #
  # Analyzes URLs to determine which job board or ATS platform is being used,
  # enabling platform-specific extraction strategies.
  #
  # @example
  #   detector = Scraping::JobBoardDetectorService.new("https://boards.greenhouse.io/company/jobs/123")
  #   detector.detect # => :greenhouse
  #   detector.company_slug # => "company"
  #   detector.job_id # => "123"
  class JobBoardDetectorService
    # Board types that have API integrations
    API_SUPPORTED_BOARDS = [ :greenhouse, :lever ].freeze

    # Board types with limited extraction capability (require auth, heavy JS, etc.)
    LIMITED_EXTRACTION_BOARDS = [ :linkedin, :indeed, :glassdoor ].freeze

    # Initialize detector with a URL
    #
    # @param [String] url The job listing URL to analyze
    def initialize(url)
      @url = url
      @uri = URI.parse(url)
    end

    # Detects the job board type from the URL
    #
    # @return [Symbol] Job board type (:linkedin, :greenhouse, :lever, etc.)
    def detect
      return :greenhouse if greenhouse?
      return :lever if lever?
      return :linkedin if linkedin?
      return :indeed if indeed?
      return :glassdoor if glassdoor?
      return :workable if workable?
      return :jobvite if jobvite?
      return :icims if icims?
      return :smartrecruiters if smartrecruiters?
      return :bamboohr if bamboohr?
      return :ashbyhq if ashbyhq?

      :unknown
    end

    # Checks if this board type has API support
    #
    # @return [Boolean] True if API integration is available
    def api_supported?
      API_SUPPORTED_BOARDS.include?(detect)
    end

    # Checks if this board type has limited extraction capability
    # (requires authentication, heavy JS rendering, or blocks scraping)
    #
    # @return [Boolean] True if extraction is limited
    def limited_extraction?
      LIMITED_EXTRACTION_BOARDS.include?(detect)
    end

    # Extracts company slug/identifier from URL
    #
    # @return [String, nil] Company identifier or nil
    def company_slug
      case detect
      when :greenhouse
        extract_greenhouse_company
      when :lever
        extract_lever_company
      when :workable
        extract_workable_company
      else
        nil
      end
    end

    # Extracts job ID from URL
    #
    # @return [String, nil] Job ID or nil
    def job_id
      # Lever URLs are typically /<company>/<job-id>
      if detect == :lever
        segments = @uri.path.to_s.split("/").reject(&:blank?)
        return segments[1] if segments.length >= 2
      end

      # LinkedIn has specific patterns
      if detect == :linkedin
        return extract_linkedin_job_id
      end

      # Try to find job ID in common patterns
      patterns = [
        %r{/jobs?/(\d+)},          # /jobs/123
        %r{/positions?/(\d+)},     # /positions/123
        %r{/careers?/(\d+)},       # /careers/123
        %r{/job/([^/\?]+)},        # /job/some-id
        %r{/position/([^/\?]+)},   # /position/some-id
        %r{job_id=([^&]+)},        # ?job_id=123
        %r{gh_jid=([^&]+)}         # Greenhouse job ID param
      ]

      patterns.each do |pattern|
        match = @url.match(pattern)
        return match[1] if match
      end

      nil
    end

    # Returns the canonical URL for this job listing
    # Useful for normalizing different URL formats that point to the same job
    #
    # @return [String] Canonical URL
    def canonical_url
      case detect
      when :linkedin
        job = extract_linkedin_job_id
        job ? "https://www.linkedin.com/jobs/view/#{job}" : @url
      else
        @url
      end
    end

    private

    # Checks if URL is from Greenhouse
    def greenhouse?
      @uri.host&.include?("greenhouse.io") ||
        @url.include?("boards.greenhouse.io") ||
        @url.include?("gh_jid=")
    end

    # Checks if URL is from Lever
    def lever?
      @uri.host&.include?("lever.co") ||
        @url.include?("jobs.lever.co")
    end

    # Checks if URL is from LinkedIn
    def linkedin?
      @uri.host&.include?("linkedin.com")
    end

    # Extracts job ID from LinkedIn URL
    # Handles multiple formats:
    #   - /jobs/view/123456789
    #   - /jobs/collections/recommended/?currentJobId=123456789
    #   - /jobs/search/?currentJobId=123456789
    #
    # @return [String, nil] Job ID or nil
    def extract_linkedin_job_id
      # Direct job view: /jobs/view/123456789
      view_match = @url.match(%r{/jobs/view/(\d+)})
      return view_match[1] if view_match

      # Collection/search with currentJobId param
      param_match = @url.match(/currentJobId=(\d+)/)
      return param_match[1] if param_match

      nil
    end

    # Checks if URL is from Indeed
    def indeed?
      @uri.host&.include?("indeed.com")
    end

    # Checks if URL is from Glassdoor
    def glassdoor?
      @uri.host&.include?("glassdoor.com")
    end

    # Checks if URL is from Workable
    def workable?
      @uri.host&.include?("workable.com") ||
        @url.include?("apply.workable.com")
    end

    # Checks if URL is from Jobvite
    def jobvite?
      @uri.host&.include?("jobvite.com")
    end

    # Checks if URL is from iCIMS
    def icims?
      @uri.host&.include?("icims.com")
    end

    # Checks if URL is from SmartRecruiters
    def smartrecruiters?
      @uri.host&.include?("smartrecruiters.com")
    end

    # Checks if URL is from BambooHR
    def bamboohr?
      @uri.host&.include?("bamboohr.com")
    end

    # Checks if URL is from Ashby
    def ashbyhq?
      @uri.host&.include?("ashbyhq.com") ||
        @uri.host&.include?("jobs.ashbyhq.com")
    end

    # Extracts company slug from Greenhouse URL
    # Example: https://boards.greenhouse.io/company-name/jobs/123
    def extract_greenhouse_company
      match = @url.match(%r{boards\.greenhouse\.io/([^/]+)})
      match ? match[1] : nil
    end

    # Extracts company slug from Lever URL
    # Example: https://jobs.lever.co/company-name/job-id
    def extract_lever_company
      match = @url.match(%r{jobs\.lever\.co/([^/]+)})
      match ? match[1] : nil
    end

    # Extracts company slug from Workable URL
    # Example: https://apply.workable.com/company-name/
    def extract_workable_company
      match = @url.match(%r{apply\.workable\.com/([^/]+)})
      match ? match[1] : nil
    end
  end
end
