# frozen_string_literal: true

# Service for scraping job listing information from URLs
#
# This service delegates to the Scraping::OrchestratorService for actual extraction.
# It maintains backward compatibility with the existing interface while using
# the new orchestration system under the hood.
#
# @example
#   service = JobListingScraperService.new(url: "https://company.com/jobs/123")
#   result = service.scrape
#   job_listing.update(scraped_data: result)
#
class JobListingScraperService
  # Initialize the service with a job listing
  #
  # @param [String] url The URL of the job listing (deprecated - use job_listing)
  # @param [JobListing] job_listing The job listing model to extract for
  def initialize(url: nil, job_listing: nil)
    if job_listing
      @job_listing = job_listing
      @url = job_listing.url
    elsif url
      # For backward compatibility - create a temporary job listing
      @url = url
      @job_listing = nil
    else
      raise ArgumentError, "Must provide either url or job_listing"
    end

    @scraped_at = Time.current
  end

  # Scrapes the job listing using the orchestration service
  #
  # @return [Hash] Scraped data including title, description, requirements, etc.
  def scrape
    # If we have a job listing model, use the orchestrator
    if @job_listing
      orchestrator = Scraping::OrchestratorService.new(@job_listing)
      success = orchestrator.call

      # Return scraped data format
      if success
        {
          scraped_at: @scraped_at.iso8601,
          source_url: @url,
          title: @job_listing.title,
          description: @job_listing.description,
          requirements: @job_listing.requirements,
          responsibilities: @job_listing.responsibilities,
          location: @job_listing.location,
          remote_type: @job_listing.remote_type,
          salary_min: @job_listing.salary_min,
          salary_max: @job_listing.salary_max,
          salary_currency: @job_listing.salary_currency,
          equity_info: @job_listing.equity_info,
          benefits: @job_listing.benefits,
          perks: @job_listing.perks,
          custom_sections: @job_listing.custom_sections,
          success: true,
          error: nil
        }
      else
        {
          scraped_at: @scraped_at.iso8601,
          source_url: @url,
          success: false,
          error: "Extraction failed - check scraping attempts for details"
        }
      end
    else
      # Fallback for URL-only usage (not recommended)
      Rails.logger.warn("JobListingScraperService called without job_listing model")
      {
        scraped_at: @scraped_at.iso8601,
        source_url: @url,
        success: false,
        error: "Job listing model required for extraction"
      }
    end
  end

  # Checks if the URL is scrapable
  #
  # @return [Boolean] True if URL can be scraped
  def scrapable?
    return false if @url.blank?

    # Check if URL is from supported job boards
    supported_domains.any? { |domain| @url.include?(domain) }
  end

  # Returns list of supported job board domains
  #
  # @return [Array<String>] List of supported domains
  def supported_domains
    [
      "linkedin.com",
      "indeed.com",
      "glassdoor.com",
      "greenhouse.io",
      "lever.co",
      "workable.com",
      "jobvite.com",
      "icims.com",
      "smartrecruiters.com",
      "bamboohr.com",
      "ashbyhq.com"
    ]
  end
end
