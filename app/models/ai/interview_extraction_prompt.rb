# frozen_string_literal: true

module Ai
  # Prompt template for extracting interview details from scheduling confirmation emails
  #
  # Used by Signals::InterviewRoundProcessor to extract structured interview data
  # from confirmation emails (Calendly, GoodTime, manual, etc.)
  #
  # Variables:
  # - {{subject}} - The email subject line
  # - {{body}} - The email body content
  # - {{from_email}} - The sender's email address
  # - {{from_name}} - The sender's display name
  # - {{company_name}} - The company name if known
  #
  class InterviewExtractionPrompt < LlmPrompt
    # Default prompt template for interview extraction
    #
    # @return [String] Default prompt template
    def self.default_prompt_template
      <<~PROMPT
        Analyze the following interview scheduling/confirmation email and extract interview details.

        FROM: {{from_name}} <{{from_email}}>
        SUBJECT: {{subject}}
        COMPANY: {{company_name}}

        EMAIL CONTENT:
        {{body}}

        Extract the following information and respond with a JSON object:

        {
          "interview": {
            "scheduled_at": "ISO 8601 datetime (e.g., '2026-01-21T14:00:00-08:00') - MUST include timezone offset",
            "duration_minutes": 30 or 45 or 60 (integer, extract from email or default to 30),
            "timezone": "Timezone name (e.g., 'PST', 'EST', 'UTC') if mentioned",
            "stage": "screening|technical|hiring_manager|culture_fit|other",
            "stage_name": "Custom stage name if mentioned (e.g., 'Technical Round 1', 'Final Interview')"
          },
          "interviewer": {
            "name": "Full name of the interviewer",
            "role": "Job title/role of the interviewer (e.g., 'Engineering Manager', 'Senior Recruiter')",
            "email": "Interviewer's email if mentioned"
          },
          "logistics": {
            "video_link": "Full URL to video conference (Zoom, Meet, Teams, etc.)",
            "phone_number": "Phone number if it's a phone interview",
            "location": "Physical location if in-person interview",
            "meeting_id": "Meeting ID/code if provided separately from link",
            "passcode": "Meeting passcode if provided"
          },
          "confirmation_source": "calendly|goodtime|greenhouse|lever|manual|other",
          "is_rescheduled": true/false,
          "is_cancelled": true/false,
          "original_scheduled_at": "ISO 8601 datetime if this is a reschedule",
          "additional_instructions": "Any prep instructions, what to bring, who to ask for, etc.",
          "confidence_score": 0.0 to 1.0
        }

        Guidelines for stage detection:
        - "screening" - Initial recruiter call, HR screen, phone screen, intro call
        - "technical" - Coding interview, system design, technical assessment, live coding
        - "hiring_manager" - Meeting with manager, team lead, direct supervisor
        - "culture_fit" - Values interview, behavioral, team fit, culture chat
        - "other" - Final round, panel, presentation, case study, on-site

        Guidelines for confirmation_source:
        - "calendly" - Calendly scheduling links/confirmations
        - "goodtime" - GoodTime scheduling platform
        - "greenhouse" - Greenhouse ATS confirmations
        - "lever" - Lever ATS confirmations
        - "manual" - Direct email from recruiter/company (no scheduling platform)
        - "other" - Other scheduling tools

        Guidelines for date/time extraction:
        - Always include timezone offset in scheduled_at (e.g., -08:00 for PST)
        - If no timezone specified, use the timezone mentioned in the email or default to UTC
        - Parse various date formats: "Tuesday, January 21st", "1/21/26", "21 Jan 2026"
        - Parse various time formats: "2:00 PM", "14:00", "2pm PST"

        Guidelines for video links:
        - Extract the full video conference URL
        - Common patterns: zoom.us/j/, meet.google.com/, teams.microsoft.com/

        Use null for any field where information is not clearly available.
        Respond ONLY with the JSON object, no additional text or markdown.
      PROMPT
    end

    # Default system prompt for interview extraction
    #
    # @return [String]
    def self.default_system_prompt
      <<~PROMPT
        You are an expert at extracting interview scheduling details from confirmation emails.
        Your goal is to accurately extract:
        - When the interview is scheduled (date, time, timezone)
        - How long it will last
        - Who the interviewer is
        - How to join (video link, phone, location)
        - What type/stage of interview it is

        Rules:
        - Return ONLY valid JSON, no markdown or commentary
        - Use null for missing information, never guess
        - Always include timezone in scheduled_at datetime
        - Be precise with video conference URLs
        - Detect rescheduling and cancellation language
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
        "company_name" => { "required" => false, "description" => "The company name if known" }
      }
    end
  end
end
