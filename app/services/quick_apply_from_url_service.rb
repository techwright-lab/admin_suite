# frozen_string_literal: true

require "timeout"

# Service for quick application creation from URL
#
# Orchestrates the entire quick apply flow:
# 1. Creates JobListing with URL
# 2. Runs extraction to get job details
# 3. Extracts company name and job role title
# 4. Creates/finds Company and JobRole
# 5. Updates JobListing with all data
# 6. Creates InterviewApplication
#
# @example
#   service = QuickApplyFromUrlService.new("https://boards.greenhouse.io/stripe/jobs/123", user)
#   result = service.call
#   if result[:success]
#     application = result[:application]
#   end
class QuickApplyFromUrlService
  EXTRACTION_TIMEOUT = 15.seconds

  # Initialize the service with URL and user
  #
  # @param [String] url The job listing URL
  # @param [User] user The user creating the application
  def initialize(url, user)
    @url = url
    @normalized_url = ScrapedJobListingData.normalize_url(url)
    @user = user
    @start_time = Time.current
  end

  # Executes the quick apply flow
  #
  # @return [Hash] Result hash with success status, application, and errors
  def call
    return error_result("URL is required") if @url.blank?
    return error_result("Invalid URL format") unless valid_url?

    # Extract company name from URL first (needed to create JobListing)
    company_name = extract_company_name_from_url || extract_company_name_from_domain
    job_role_title = "Unknown Position" # Placeholder, will be updated after extraction

    # Find or create Company and JobRole (with placeholder values)
    company = find_or_create_company(company_name)
    job_role = find_or_create_job_role(job_role_title)

    # Create JobListing with company and job_role (required for validations)
    job_listing = create_job_listing(company, job_role)

    # Run extraction synchronously
    # The orchestrator will extract and update company and job_role on the job listing
    run_extraction(job_listing)

    # After extraction, use the company and job_role that were set by the orchestrator
    # The orchestrator already extracted and updated these fields correctly
    job_listing.reload
    company = job_listing.company
    job_role = job_listing.job_role

    # Create InterviewApplication using the company and job_role from the job listing
    application = create_application(job_listing, company, job_role)

    {
      success: true,
      application: application,
      job_listing: job_listing,
      company: company,
      job_role: job_role,
      extraction_time: Time.current - @start_time
    }
  rescue => e
    Rails.logger.error("QuickApplyFromUrlService failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    error_result(e.message)
  end

  private

  # Validates URL format
  #
  # @return [Boolean] True if URL is valid
  def valid_url?
    uri = URI.parse(@url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  # Creates a JobListing with URL, company, and job_role
  #
  # @param [Company] company The company
  # @param [JobRole] job_role The job role
  # @return [JobListing] The created job listing
  def create_job_listing(company, job_role)
    job_listing = JobListing.find_or_initialize_by(url: @normalized_url)

    # Set attributes if it's a new record
    if job_listing.new_record?
      job_listing.company = company
      job_listing.job_role = job_role
      job_listing.status = :active
      job_listing.source_id = extract_source_id(@normalized_url)
      job_listing.custom_sections = (job_listing.custom_sections || {}).merge("original_url" => @url)
      job_listing.save!
    end

    job_listing
  end

  # Runs extraction synchronously with timeout
  #
  # @param [JobListing] job_listing The job listing to extract for
  # @return [Hash] Result hash with success status and extracted data
  def run_extraction(job_listing)
    # Use orchestrator service for extraction
    orchestrator = Scraping::OrchestratorService.new(job_listing)

    # Run with timeout - but use a thread so we don't interrupt the orchestrator
    # This allows the extraction to continue even if we timeout waiting for it
    extraction_thread = Thread.new do
      Thread.current[:result] = orchestrator.call
    end

    # Wait for completion with timeout
    completed = extraction_thread.join(EXTRACTION_TIMEOUT)

    if completed
      success = extraction_thread[:result]
      job_listing.reload

      if success && job_listing.extraction_completed?
        {
          success: true,
          data: {}
        }
      else
        {
          success: false,
          error: "Extraction failed"
        }
      end
    else
      # Timeout waiting for extraction - it's still running in the background thread
      # Queue a background job to handle completion/retry
      handle_extraction_timeout(job_listing)
    end
  rescue => e
    Rails.logger.error("Extraction error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    {
      success: false,
      error: e.message
    }
  end

  # Handles timeout by queuing background job if needed
  #
  # @param job_listing [JobListing] The job listing being extracted
  # @return [Hash] Result hash
  def handle_extraction_timeout(job_listing)
    latest_attempt = job_listing.scraping_attempts.order(created_at: :desc).first

    # Always queue a background job to monitor/complete the extraction
    # The extraction might still be running, but if it fails, the job will handle it
    if latest_attempt
      # Queue with delay to give the current extraction time to complete
      ScrapeJobListingJob.set(wait: 30.seconds).perform_later(job_listing)

      Rails.logger.info({
        event: "extraction_timeout_job_queued",
        job_listing_id: job_listing.id,
        scraping_attempt_id: latest_attempt.id,
        attempt_status: latest_attempt.status
      }.to_json)
    end

    {
      success: false,
      error: "Extraction is taking longer than expected. Processing in background..."
    }
  end

  # Extracts company name from various sources
  #
  # @param [JobListing] job_listing The job listing
  # @param [Hash] extracted_data The extracted data
  # @return [String] Company name
  def extract_company_name(job_listing, extracted_data)
    # Try company slug from URL first
    company_name = extract_company_name_from_url

    # If we have extracted data with company field, use that
    company_name = extracted_data[:company] if extracted_data[:company].present?

    # Fallback to domain name
    company_name ||= extract_company_name_from_domain

    normalize_company_name(company_name)
  end

  # Extracts company name from URL patterns
  #
  # @return [String, nil] Company name or nil
  def extract_company_name_from_url
    detector = Scraping::JobBoardDetectorService.new(@url)
    company_slug = detector.company_slug

    return nil unless company_slug

    # Convert slug to readable name
    # e.g., "stripe" -> "Stripe", "acme-corp" -> "Acme Corp"
    company_slug
      .gsub(/[-_]/, " ")
      .split
      .map(&:capitalize)
      .join(" ")
  end

  # Extracts company name from domain
  #
  # @return [String] Company name from domain
  def extract_company_name_from_domain
    uri = URI.parse(@url)
    domain = uri.host

    # Remove www. prefix
    domain = domain.sub(/^www\./, "")

    # Extract base domain (e.g., "stripe.com" -> "stripe")
    base = domain.split(".").first

    # Convert to readable name
    base.gsub(/[-_]/, " ").split.map(&:capitalize).join(" ")
  rescue
    "Unknown Company"
  end

  # Extracts company from scraped data if available
  #
  # @param [JobListing] job_listing The job listing
  # @return [String, nil] Company name or nil
  def extract_company_from_scraped_data(job_listing)
    # Check if company name is in custom_sections or scraped_data
    job_listing.custom_sections&.dig("company") ||
      job_listing.scraped_data&.dig("company")
  end

  # Extracts job role title from scraped data
  #
  # @param [JobListing] job_listing The job listing
  # @param [Hash] extracted_data The extracted data
  # @return [String] Job role title
  def extract_job_role_title(job_listing, extracted_data)
    title = extracted_data[:title] || job_listing.title

    return "Unknown Position" if title.blank?

    normalize_job_role_title(title)
  end

  # Normalizes company name for matching
  #
  # @param [String] name The company name
  # @return [String] Normalized name
  def normalize_company_name(name)
    return "Unknown Company" if name.blank?

    name.strip.titleize
  end

  # Normalizes job role title for matching
  #
  # @param [String] title The job role title
  # @return [String] Normalized title
  def normalize_job_role_title(title)
    return "Unknown Position" if title.blank?

    title.strip
  end

  # Finds or creates a Company
  #
  # @param [String] name The company name
  # @return [Company] The company record
  def find_or_create_company(name)
    normalized_name = normalize_company_name(name)

    Company.find_or_create_by(name: normalized_name) do |company|
      # Extract website from URL if possible
      uri = URI.parse(@url)
      company.website = "#{uri.scheme}://#{uri.host}" if uri.host
    end
  end

  # Finds or creates a JobRole
  #
  # @param [String] title The job role title
  # @return [JobRole] The job role record
  def find_or_create_job_role(title)
    normalized_title = normalize_job_role_title(title)

    JobRole.find_or_create_by(title: normalized_title)
  end

  # Creates an InterviewApplication
  #
  # @param [JobListing] job_listing The job listing
  # @param [Company] company The company
  # @param [JobRole] job_role The job role
  # @return [InterviewApplication] The created application
  def create_application(job_listing, company, job_role)
    application = @user.interview_applications.find_or_initialize_by(job_listing: job_listing)
    application.company = company
    application.job_role = job_role
    application.applied_at ||= Date.today
    application.save!
    application
  end

  # Extracts source ID from URL
  #
  # @param [String] url The URL
  # @return [String, nil] Source ID or nil
  def extract_source_id(url)
    match = url.match(%r{/(jobs?|careers?|positions?)/([^/\?]+)})
    match ? match[2] : nil
  end

  # Returns an error result hash
  #
  # @param [String] error_message The error message
  # @return [Hash] Error result hash
  def error_result(error_message)
    {
      success: false,
      error: error_message,
      application: nil
    }
  end
end
