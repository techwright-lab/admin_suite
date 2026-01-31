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

    res = JobListings::UpsertFromUrlService.new(
      url: @url,
      company: @application.company,
      job_role: @application.job_role,
      title: @application.job_role.title
    ).call

    job_listing = res[:job_listing]

    # Associate with the application
    @application.update(job_listing: job_listing)

    # Trigger scraping if we haven't successfully scraped yet
    ScrapeJobListingJob.perform_later(job_listing) unless job_listing.scraped?

    job_listing
  rescue => e
    Rails.logger.error "Failed to create job listing from URL: #{e.message}"
    nil
  end

  private
end
