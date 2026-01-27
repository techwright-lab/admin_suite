# frozen_string_literal: true

module Signals
  module Actions
    # Creates a new interview application from extracted signal data
    #
    # Uses the company name, job title, and other extracted information
    # to create a new InterviewApplication record and optionally a Company.
    # If a job URL is detected, also creates a JobListing and triggers scraping.
    #
    # @example
    #   action = StartApplicationAction.new(synced_email, user, {})
    #   result = action.execute
    #   # => { success: true, application: InterviewApplication, company: Company, job_listing: JobListing }
    #
    class StartApplicationAction < BaseAction
      # Job URL detection patterns for action links
      JOB_LINK_LABELS = /view.*job|job.*posting|apply|see.*position|full.*description|job.*details/i
      JOB_URL_PATTERNS = /lever\.co|greenhouse\.io|workday|myworkday|jobs\.|careers\.|ashbyhq\.com|smartrecruiters|jobvite|icims|bamboohr/i

      # Executes the action to create a new application
      #
      # @return [Hash] Result with created application and company
      def execute
        return failure_result("No company name extracted") unless company_name.present?

        ActiveRecord::Base.transaction do
          # Find or create the company (global model)
          company = find_or_create_company

          # Find or create job role
          job_role = find_or_create_job_role

          # Create job listing if we have a URL
          job_listing = create_job_listing_if_url_present(company, job_role)

          # Create the application with optional job listing
          application = create_application(company, job_role, job_listing)

          # Link the email to the application
          synced_email.match_to_application!(application)

          # Trigger job listing scraping in background if we have a new listing
          if job_listing.present? && job_listing.extraction_status == "pending"
            ScrapeJobListingJob.perform_later(job_listing)
          end

          success_result(
            "Application started at #{company.name}",
            application: application,
            company: company,
            job_listing: job_listing,
            redirect_path: Rails.application.routes.url_helpers.interview_application_path(application)
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        failure_result("Failed to create application: #{e.message}")
      end

      private

      # Finds or creates a company from extracted data
      # Note: Company is a global model, not user-scoped
      #
      # @return [Company]
      def find_or_create_company
        normalized_name = normalize_company_name(company_name)

        # Try to find existing company by name (case-insensitive)
        existing = Company.find_by("LOWER(name) = ?", normalized_name.downcase)
        
        if existing
          # Update website if we have one and it's missing
          if company_website.present? && existing.website.blank?
            existing.update(website: company_website)
          end
          return existing
        end

        # Create new company with extracted data
        Company.create!(
          name: normalized_name,
          website: company_website
        )
      end

      # Finds or creates a job role from extracted data
      #
      # @return [JobRole]
      def find_or_create_job_role
        role_title = job_title.presence || "Position via #{recruiter_name || 'Recruiter'}"

        # Try to find existing
        existing = JobRole.find_by("LOWER(title) = ?", role_title.downcase)
        return existing if existing

        # Create new job role
        JobRole.create!(title: role_title)
      end

      # Detects job URL from extracted signals
      # Checks signal_job_url first, then looks in action_links for job-related URLs
      #
      # @return [String, nil]
      def detected_job_url
        # Priority 1: Direct job URL from signal extraction
        return job_url if job_url.present?

        # Priority 2: Look in action_links for job-related URLs
        return nil unless synced_email.signal_action_links.is_a?(Array)

        job_link = synced_email.signal_action_links.find do |link|
          next unless link.is_a?(Hash)

          label = link["action_label"].to_s
          url = link["url"].to_s

          # Match labels that indicate job postings
          next true if label.match?(JOB_LINK_LABELS)

          # Match URLs that look like job posting platforms
          next true if url.match?(JOB_URL_PATTERNS)

          false
        end

        job_link&.dig("url")
      end

      # Creates a job listing if we have a URL
      # Finds existing listing by URL or creates a new one
      #
      # @param company [Company] The company
      # @param job_role [JobRole] The job role
      # @return [JobListing, nil]
      def create_job_listing_if_url_present(company, job_role)
        url = detected_job_url
        return nil unless url.present?

        # Normalize URL for comparison
        normalized_url = normalize_job_url(url)

        # Check if job listing already exists for this URL
        existing = JobListing.find_by(url: normalized_url)
        return existing if existing

        # Also check without query params for some URLs
        base_url = normalized_url.split("?").first
        existing_base = JobListing.find_by(url: base_url) if base_url != normalized_url
        return existing_base if existing_base

        # Create new job listing (extraction_status defaults to "pending" via scraped_data)
        JobListing.create!(
          url: normalized_url,
          company: company,
          job_role: job_role,
          title: job_title.presence || "#{job_role.title} at #{company.name}",
          status: :active
        )
      end

      # Normalizes a job URL for consistent storage
      #
      # @param url [String] The raw URL
      # @return [String]
      def normalize_job_url(url)
        uri = URI.parse(url.strip)
        # Remove tracking parameters but keep job-specific ones
        if uri.query.present?
          params = URI.decode_www_form(uri.query).reject do |key, _|
            # Remove common tracking params
            %w[utm_source utm_medium utm_campaign utm_content utm_term ref source].include?(key.downcase)
          end
          uri.query = params.any? ? URI.encode_www_form(params) : nil
        end
        uri.to_s
      rescue URI::InvalidURIError
        url.strip
      end

      # Creates the interview application
      #
      # @param company [Company] The company
      # @param job_role [JobRole] The job role
      # @param job_listing [JobListing, nil] Optional job listing
      # @return [InterviewApplication]
      def create_application(company, job_role, job_listing = nil)
        user.interview_applications.create!(
          company: company,
          job_role: job_role,
          job_listing: job_listing,
          applied_at: synced_email.email_date || Time.current,
          notes: build_application_notes
        )
      end

      # Normalizes company name
      #
      # @param name [String]
      # @return [String]
      def normalize_company_name(name)
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

      # Builds notes for the application
      # Uses emoji and clean formatting for readability
      #
      # @return [String]
      def build_application_notes
        lines = []

        lines << "📬 Created from email signal"
        lines << ""

        # Recruiter section
        if recruiter_name.present?
          lines << "👤 RECRUITER"
          lines << "   #{recruiter_name}"
          lines << "   #{synced_email.signal_recruiter_title}" if synced_email.signal_recruiter_title.present?
          lines << "   #{recruiter_email}" if recruiter_email.present?
          lines << ""
        end

        # Job details section
        details = []
        details << "📍 #{synced_email.signal_job_location}" if synced_email.signal_job_location.present?
        details << "🏢 #{synced_email.signal_job_department}" if synced_email.signal_job_department.present?
        details << "💰 #{synced_email.signal_job_salary_hint}" if synced_email.signal_job_salary_hint.present?
        
        if details.any?
          lines << "📋 DETAILS"
          details.each { |d| lines << "   #{d.sub(/^.{2}/, '')}" } # Remove emoji from sub-items
          lines << ""
        end

        # Scheduling link (friendly name, not raw URL)
        if scheduling_link.present?
          friendly_name = extract_scheduling_platform(scheduling_link)
          lines << "📅 NEXT STEP"
          lines << "   Schedule via #{friendly_name}"
        end

        lines.join("\n").strip
      end

      # Extracts a friendly platform name from scheduling URL
      #
      # @param url [String]
      # @return [String]
      def extract_scheduling_platform(url)
        case url
        when /goodtime\.io/i then "GoodTime"
        when /calendly\.com/i then "Calendly"
        when /cal\.com/i then "Cal.com"
        when /doodle\.com/i then "Doodle"
        when /zoom\.us.*schedule/i then "Zoom"
        when /meet\.google/i then "Google Meet"
        else "scheduling link"
        end
      end
    end
  end
end
