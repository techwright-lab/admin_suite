# frozen_string_literal: true

module Gmail
  # Service for detecting recruiter outreach emails
  # Distinguishes between application-related emails and unsolicited recruiter contact
  #
  # @example
  #   detector = Gmail::OpportunityDetectorService.new(synced_email)
  #   if detector.recruiter_outreach?
  #     opportunity = detector.create_opportunity!
  #   end
  #
  class OpportunityDetectorService
    # Keywords that indicate recruiter outreach (not application-related)
    OUTREACH_KEYWORDS = [
      # Direct outreach phrases
      "opportunity",
      "exciting role",
      "perfect fit",
      "great fit",
      "your profile",
      "your background",
      "your experience",
      "reaching out",
      "interested in you",
      "open position",
      "hiring for",
      "would you be interested",
      "great match",
      "ideal candidate",
      "thought of you",
      "came across your",
      "found your profile",
      "saw your resume",
      "impressive background",
      "looking for someone",
      "we have an opening",
      "new opportunity",
      "career opportunity"
    ].freeze

    # Keywords that indicate this is a reply to an application (NOT outreach)
    APPLICATION_KEYWORDS = [
      "thank you for applying",
      "your application",
      "application received",
      "application status",
      "interview scheduled",
      "interview confirmed",
      "next steps in the process",
      "move forward with your",
      "following up on your application"
    ].freeze

    # Domains that typically send recruiter outreach
    RECRUITER_DOMAINS = [
      "linkedin.com",
      "mail.linkedin.com",
      "hired.com",
      "angel.co",
      "wellfound.com",
      "dice.com",
      "indeed.com",
      "ziprecruiter.com",
      "glassdoor.com",
      "monster.com"
    ].freeze

    # Title patterns for recruiters
    RECRUITER_TITLE_PATTERNS = [
      /recruiter/i,
      /talent\s*(acquisition|partner|scout)/i,
      /sourcer/i,
      /headhunter/i,
      /staffing/i,
      /hr\s*manager/i,
      /hiring\s*manager/i,
      /people\s*ops/i
    ].freeze

    # Patterns indicating forwarded messages
    FORWARDED_PATTERNS = [
      /fwd?:/i,
      /forwarded message/i,
      /---------- Forwarded message/i,
      /Begin forwarded message/i
    ].freeze

    # LinkedIn-specific patterns
    LINKEDIN_PATTERNS = [
      /linkedin\.com/i,
      /sent you a message/i,
      /wants to connect/i,
      /InMail/i,
      /via LinkedIn/i
    ].freeze

    # @return [SyncedEmail] The email to analyze
    attr_reader :synced_email

    # Initialize the detector
    #
    # @param synced_email [SyncedEmail] The email to analyze
    def initialize(synced_email)
      @synced_email = synced_email
    end

    # Checks if this email is recruiter outreach
    #
    # @return [Boolean] True if this appears to be recruiter outreach
    def recruiter_outreach?
      return false if application_related?

      outreach_score >= 0.5
    end

    # Returns a confidence score for recruiter outreach detection
    #
    # @return [Float] Score between 0 and 1
    def outreach_score
      score = 0.0
      total_weight = 0.0

      # Check outreach keywords (weight: 0.4)
      if has_outreach_keywords?
        score += 0.4
      end
      total_weight += 0.4

      # Check recruiter sender patterns (weight: 0.3)
      if from_recruiter?
        score += 0.3
      end
      total_weight += 0.3

      # Check for LinkedIn/job board forwarding (weight: 0.2)
      if forwarded_from_job_platform?
        score += 0.2
      end
      total_weight += 0.2

      # Check if first contact (no thread history) (weight: 0.1)
      if first_contact?
        score += 0.1
      end
      total_weight += 0.1

      score / total_weight
    end

    # Detects the source type of the opportunity
    #
    # @return [String] One of: direct_email, linkedin_forward, referral, other
    def detect_source_type
      if linkedin_forward?
        "linkedin_forward"
      elsif has_referral_indicators?
        "referral"
      elsif from_recruiter?
        "direct_email"
      else
        "other"
      end
    end

    # Checks if this is a forwarded email
    #
    # @return [Boolean]
    def forwarded?
      content = combined_content
      FORWARDED_PATTERNS.any? { |pattern| content.match?(pattern) }
    end

    # Checks if this is forwarded from LinkedIn
    #
    # @return [Boolean]
    def linkedin_forward?
      content = combined_content
      from_domain = extract_domain(synced_email.from_email)

      # Check if from LinkedIn or mentions LinkedIn
      from_domain == "linkedin.com" ||
        from_domain == "mail.linkedin.com" ||
        LINKEDIN_PATTERNS.any? { |pattern| content.match?(pattern) }
    end

    # Creates an Opportunity from this email
    #
    # @return [Opportunity] The created opportunity
    def create_opportunity!
      Opportunity.create!(
        user: synced_email.user,
        synced_email: synced_email,
        status: "new",
        source_type: detect_source_type,
        recruiter_name: synced_email.from_name,
        recruiter_email: synced_email.from_email,
        email_snippet: synced_email.snippet || synced_email.body_preview&.truncate(500),
        ai_confidence_score: outreach_score,
        extracted_data: {
          is_forwarded: forwarded?,
          original_source: detect_original_source
        }
      )
    end

    private

    # Returns combined content for analysis
    #
    # @return [String]
    def combined_content
      [
        synced_email.subject,
        synced_email.snippet,
        synced_email.body_preview
      ].compact.join(" ").downcase
    end

    # Checks if content has outreach keywords
    #
    # @return [Boolean]
    def has_outreach_keywords?
      content = combined_content
      OUTREACH_KEYWORDS.any? { |keyword| content.include?(keyword.downcase) }
    end

    # Checks if this appears to be application-related (not outreach)
    #
    # @return [Boolean]
    def application_related?
      content = combined_content
      APPLICATION_KEYWORDS.any? { |keyword| content.include?(keyword.downcase) }
    end

    # Checks if sender appears to be a recruiter
    #
    # @return [Boolean]
    def from_recruiter?
      # Check sender name for recruiter title patterns
      if synced_email.from_name.present?
        return true if RECRUITER_TITLE_PATTERNS.any? { |pattern| synced_email.from_name.match?(pattern) }
      end

      # Check if from recruiter domain
      domain = extract_domain(synced_email.from_email)
      RECRUITER_DOMAINS.include?(domain)
    end

    # Checks if forwarded from a job platform
    #
    # @return [Boolean]
    def forwarded_from_job_platform?
      linkedin_forward? || (forwarded? && from_recruiter?)
    end

    # Checks if this is the first contact in a thread
    #
    # @return [Boolean]
    def first_contact?
      return true if synced_email.thread_id.blank?

      synced_email.thread_count == 1
    end

    # Checks for referral indicators
    #
    # @return [Boolean]
    def has_referral_indicators?
      content = combined_content
      referral_patterns = [
        /referred by/i,
        /recommended you/i,
        /suggested I reach out/i,
        /your colleague/i,
        /mutual connection/i
      ]
      referral_patterns.any? { |pattern| content.match?(pattern) }
    end

    # Detects the original source of the opportunity
    #
    # @return [String, nil]
    def detect_original_source
      if linkedin_forward?
        "linkedin"
      elsif forwarded?
        "forwarded"
      else
        nil
      end
    end

    # Extracts domain from email address
    #
    # @param email [String] Email address
    # @return [String] Domain portion
    def extract_domain(email)
      return "" if email.blank?

      email.split("@").last&.downcase || ""
    end
  end
end
