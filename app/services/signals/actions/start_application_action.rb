# frozen_string_literal: true

module Signals
  module Actions
    # Creates a new interview application from extracted signal data
    #
    # Uses the company name, job title, and other extracted information
    # to create a new InterviewApplication record and optionally a Company.
    #
    # @example
    #   action = StartApplicationAction.new(synced_email, user, {})
    #   result = action.execute
    #   # => { success: true, application: InterviewApplication, company: Company }
    #
    class StartApplicationAction < BaseAction
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

          # Create the application
          application = create_application(company, job_role)

          # Link the email to the application
          synced_email.match_to_application!(application)

          success_result(
            "Application started at #{company.name}",
            application: application,
            company: company,
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

      # Creates the interview application
      #
      # @param company [Company] The company
      # @param job_role [JobRole] The job role
      # @return [InterviewApplication]
      def create_application(company, job_role)
        user.interview_applications.create!(
          company: company,
          job_role: job_role,
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
