# frozen_string_literal: true

module Ai
  # Prompt template for extracting actionable signals from interview-related emails
  #
  # Used by Signals::ExtractionService to extract structured intelligence
  # from email content including company info, recruiter details, job information,
  # relevant links, and suggested actions.
  #
  # Variables:
  # - {{subject}} - The email subject line
  # - {{body}} - The email body content
  # - {{from_email}} - The sender's email address
  # - {{from_name}} - The sender's display name
  # - {{email_type}} - The classified email type (interview_invite, recruiter_outreach, etc.)
  #
  class SignalExtractionPrompt < LlmPrompt
    # Default prompt template for signal extraction
    #
    # @return [String] Default prompt template
    def self.default_prompt_template
      <<~PROMPT
        Analyze the following interview-related email and extract actionable intelligence.
        The email has been classified as: {{email_type}}

        FROM: {{from_name}} <{{from_email}}>
        SUBJECT: {{subject}}

        EMAIL CONTENT:
        {{body}}

        Extract the following information and respond with a JSON object:

        {
          "company": {
            "name": "The company with the job opening (extract from signature, domain, or content)",
            "website": "Company website URL if mentioned or derivable from email domain",
            "careers_url": "URL to careers/jobs page if found",
            "domain": "Industry domain (e.g., 'FinTech', 'SaaS', 'Healthcare', 'E-commerce', 'AI/ML', etc.)"
          },
          "recruiter": {
            "name": "Recruiter/sender's full name",
            "email": "Recruiter's email address (may differ from sender if forwarded)",
            "title": "Recruiter's job title (e.g., 'Senior Recruiter', 'Talent Acquisition Manager')",
            "linkedin_url": "Recruiter's LinkedIn profile URL if found"
          },
          "job": {
            "title": "Job title or role being discussed",
            "department": "Department (Engineering, Product, Design, Data Science, etc.)",
            "location": "Job location (city, remote, hybrid, etc.)",
            "url": "Direct URL to the job posting or application page",
            "salary_hint": "Any mention of compensation, salary range, or benefits"
          },
          "action_links": [
            {
              "url": "Full URL found in the email",
              "action_label": "Human-readable action button text (e.g., 'Schedule Interview', 'View Job at Toptal', 'Apply Now', 'Learn About Our Culture')",
              "priority": 1-5 (1=most important action, 5=least important)
            }
          ],
          "suggested_actions": [
            "Array of backend actions (usually empty - UI handles most actions automatically)",
            "Only include: start_application (if this is clearly a NEW opportunity worth tracking as an application)"
          ],
          "key_insights": "Brief summary of important details (tech stack, team size, interview process, timeline, etc.)",
          "is_forwarded": true/false,
          "confidence_score": 0.0 to 1.0
        }

        Guidelines for action_links:
        - Include only the MOST RELEVANT links
        - Prefer direct, first-party links (avoid redirect wrappers)
        - Generate ACTIONABLE button labels that tell the user what clicking will do
        - Include company name in labels when relevant (e.g., "View Toptal Careers" not just "View Careers")
        - For scheduling links (calendly, goodtime, etc.), use labels like "Schedule Interview" or "Book Call"
        - For interview joins, use "Join [Company] Interview" or "Join Zoom Interview"
        - For job postings, use "View Job Posting" or "Apply for [Role]"
        - For company pages, use "Learn About [Company]" or "Visit [Company] Website"
        - Exclude low-value or boilerplate links (unsubscribe, view in browser, privacy, terms, help, forwarding guides, calendar event details, generic Google Calendar links)
        - Prioritize: 1=scheduling/join/apply, 2=job posting, 3=company info, 4=recruiter profile
        - Only include links that provide value to the job seeker

        Guidelines for suggested_actions:
        - start_application: Include ONLY if this is clearly a new opportunity (e.g., recruiter outreach, interview invite)
        - Most emails don't need suggested_actions - the UI provides matching functionality
        - Company and recruiter info is saved automatically, no action needed

        Other guidelines:
        - Extract company name from email signature, domain, or content
        - If sender email domain is a company domain (not gmail/outlook/etc.), use it to derive company website
        - Use null for any field where information is not clearly available
        - confidence_score should reflect overall extraction quality (0.0-1.0)

        Respond ONLY with the JSON object, no additional text or markdown.
      PROMPT
    end

    # Default system prompt for signal extraction
    #
    # @return [String]
    def self.default_system_prompt
      <<~PROMPT
        You are an expert at extracting actionable intelligence from interview and recruiting emails.
        Your goal is to identify key information that helps job seekers take action:
        - Company details for research
        - Recruiter contact info for follow-up
        - Job details for application tracking
        - Scheduling links for booking interviews
        - Relevant actions the user should take

        Rules:
        - Return ONLY valid JSON, no markdown or commentary
        - Use null for missing information, never guess
        - Extract URLs exactly as they appear, but avoid redirect wrappers when possible
        - Avoid returning long, exhaustive link lists
        - Be conservative with confidence scores
      PROMPT
    end

    # Returns the expected variables for this prompt type
    #
    # @return [Hash] Variable definitions
    def self.default_variables
      {
        "subject" => { "required" => true, "description" => "The email subject line" },
        "body" => { "required" => true, "description" => "The email body content" },
        "from_email" => { "required" => true, "description" => "The sender's email address" },
        "from_name" => { "required" => false, "description" => "The sender's display name" },
        "email_type" => { "required" => false, "description" => "The classified email type" }
      }
    end
  end
end
