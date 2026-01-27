# frozen_string_literal: true

# Service for creating or finding a job listing from a URL
#
# @example
#   service = CreateJobListingFromUrlService.new(application, "https://example.com/jobs/123")
#   job_listing = service.call
#
class CreateJobListingFromUrlService
  # Initialize the service with an application and URL
  #
  # @param [InterviewApplication] application The interview application
  # @param [String] url The job listing URL
  def initialize(application, url)
    @application = application
    @url = url
  end

  # Creates or finds a job listing and associates it with the application
  #
  # @return [JobListing, nil] The job listing or nil if creation failed
  def call
    return nil if @url.blank?

    normalized_url = normalize_url(@url)

    # Find existing job listing by URL or create a new one
    job_listing = JobListing.find_or_initialize_by(url: normalized_url)

    if job_listing.new_record?
      # Set basic attributes from the application
      job_listing.company = @application.company
      job_listing.job_role = @application.job_role
      job_listing.title = @application.job_role.title
      job_listing.status = :active
      job_listing.source_id = extract_source_id(@url)

      if job_listing.save
        # Associate with the application
        @application.update(job_listing: job_listing)

        # Queue background job to scrape details
        ScrapeJobListingJob.perform_later(job_listing)
      end
    else
      # Just associate existing listing with the application
      @application.update(job_listing: job_listing)
      # Trigger scraping if we haven't successfully scraped yet
      ScrapeJobListingJob.perform_later(job_listing) unless job_listing.scraped?
    end

    job_listing
  rescue => e
    Rails.logger.error "Failed to create job listing from URL: #{e.message}"
    nil
  end

  private

  # Extract a source ID from the URL
  #
  # @param [String] url The URL to extract from
  # @return [String, nil] The extracted ID or nil
  def extract_source_id(url)
    # Try to extract an ID from common URL patterns
    # e.g., /jobs/123, /careers/456, etc.
    match = url.match(%r{/(jobs?|careers?|positions?)/([^/\?]+)})
    match ? match[2] : nil
  end

  # Normalizes a job listing URL by removing common tracking parameters
  #
  # @param [String] url The URL to normalize
  # @return [String] Normalized URL
  def normalize_url(url)
    uri = URI.parse(url.strip)
    return url.strip unless uri.query.present?

    params = URI.decode_www_form(uri.query).reject do |key, _|
      %w[utm_source utm_medium utm_campaign utm_content utm_term ref source].include?(key.downcase)
    end
    uri.query = params.any? ? URI.encode_www_form(params) : nil
    uri.to_s
  rescue URI::InvalidURIError
    url.strip
  end
end
