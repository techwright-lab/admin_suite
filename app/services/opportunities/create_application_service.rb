# frozen_string_literal: true

module Opportunities
  # Service for creating an interview application from an opportunity
  #
  # Handles the full apply flow:
  # 1. Find or create Company from extracted name
  # 2. Find or create JobRole from extracted title
  # 3. If URL exists: create JobListing + trigger scraping
  # 4. If no URL: create application without job listing
  # 5. Link opportunity to interview_application
  #
  # @example
  #   service = Opportunities::CreateApplicationService.new(opportunity, user)
  #   result = service.call
  #   if result[:success]
  #     redirect_to result[:application]
  #   end
  #
  class CreateApplicationService
    attr_reader :opportunity, :user

    # Initialize the service
    #
    # @param opportunity [Opportunity] The opportunity to create an application from
    # @param user [User] The user creating the application
    def initialize(opportunity, user)
      @opportunity = opportunity
      @user = user
    end

    # Creates the interview application
    #
    # @return [Hash] Result with success status and application
    def call
      return error_result("Opportunity not found") unless opportunity
      return error_result("User not found") unless user
      return error_result("Already applied") if opportunity.applied?

      ActiveRecord::Base.transaction do
        # Find or create company
        company = find_or_create_company

        # Find or create job role
        job_role = find_or_create_job_role

        # Create job listing if we have a URL
        job_listing = create_job_listing_if_url_present(company, job_role)

        # Create the interview application
        application = create_application(company, job_role, job_listing)

        # Link opportunity to application and mark as applied
        opportunity.update!(
          interview_application: application
        )
        opportunity.mark_applied!

        # Trigger job listing scraping in background if we have a URL
        if job_listing.present?
          ScrapeJobListingJob.perform_later(job_listing)
        end

        {
          success: true,
          application: application,
          job_listing: job_listing,
          company: company,
          job_role: job_role
        }
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Opportunities::CreateApplicationService validation error: #{e.message}")
      error_result(e.message)
    rescue StandardError => e
      Rails.logger.error("Opportunities::CreateApplicationService error: #{e.message}")
      error_result("Failed to create application: #{e.message}")
    end

    private

    # Finds or creates a company from the opportunity
    #
    # @return [Company]
    def find_or_create_company
      company_name = opportunity.company_name.presence || "Unknown Company"

      # Normalize name
      normalized_name = normalize_company_name(company_name)

      # Try to find existing
      company = Company.find_by("LOWER(name) = ?", normalized_name.downcase)
      return company if company

      # Create new company
      Company.create!(name: normalized_name)
    end

    # Finds or creates a job role from the opportunity
    #
    # @return [JobRole]
    def find_or_create_job_role
      role_title = opportunity.job_role_title.presence || "Unknown Position"

      # Try to find existing
      job_role = JobRole.find_by("LOWER(title) = ?", role_title.downcase)
      return job_role if job_role

      # Create new job role
      JobRole.create!(title: role_title)
    end

    # Creates a job listing if we have a URL
    #
    # @param company [Company]
    # @param job_role [JobRole]
    # @return [JobListing, nil]
    def create_job_listing_if_url_present(company, job_role)
      return nil unless opportunity.job_url.present?

      # Check if job listing already exists for this URL
      existing = JobListing.find_by(url: opportunity.job_url)
      return existing if existing

      # Create new job listing
      JobListing.create!(
        url: opportunity.job_url,
        company: company,
        job_role: job_role,
        title: opportunity.job_role_title,
        status: :active,
        source_id: extract_source_id(opportunity.job_url)
      )
    end

    # Creates the interview application
    #
    # @param company [Company]
    # @param job_role [JobRole]
    # @param job_listing [JobListing, nil]
    # @return [InterviewApplication]
    def create_application(company, job_role, job_listing)
      user.interview_applications.create!(
        company: company,
        job_role: job_role,
        job_listing: job_listing,
        applied_at: Time.current,
        notes: build_application_notes
      )
    end

    # Builds notes for the application from opportunity data
    #
    # @return [String, nil]
    def build_application_notes
      notes_parts = []

      notes_parts << "Source: #{opportunity.source_type_display}" if opportunity.source_type.present?

      if opportunity.recruiter_name.present? || opportunity.recruiter_email.present?
        recruiter_info = [ opportunity.recruiter_name, opportunity.recruiter_email ].compact.join(" - ")
        notes_parts << "Recruiter: #{recruiter_info}"
      end

      notes_parts << "Key details: #{opportunity.key_details}" if opportunity.key_details.present?

      notes_parts.any? ? notes_parts.join("\n\n") : nil
    end

    # Normalizes company name
    #
    # @param name [String]
    # @return [String]
    def normalize_company_name(name)
      # Remove common suffixes
      normalized = name.strip
      suffixes = [
        /\s+inc\.?$/i,
        /\s+llc\.?$/i,
        /\s+corp\.?$/i,
        /\s+ltd\.?$/i,
        /\s+co\.?$/i
      ]

      suffixes.each { |suffix| normalized = normalized.gsub(suffix, "") }
      normalized.strip.titleize
    end

    # Extracts source ID from URL
    #
    # @param url [String]
    # @return [String, nil]
    def extract_source_id(url)
      match = url.match(%r{/(jobs?|careers?|positions?)/([^/\?]+)})
      match ? match[2] : nil
    end

    # Returns an error result
    #
    # @param message [String]
    # @return [Hash]
    def error_result(message)
      {
        success: false,
        error: message,
        application: nil
      }
    end
  end
end
