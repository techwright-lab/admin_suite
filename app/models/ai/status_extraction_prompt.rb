# frozen_string_literal: true

module Ai
  # Prompt template for extracting application status changes from emails
  #
  # Used by Signals::ApplicationStatusProcessor to extract rejection, offer,
  # and status update information from emails.
  #
  # Variables:
  # - {{subject}} - The email subject line
  # - {{body}} - The email body content
  # - {{from_email}} - The sender's email address
  # - {{from_name}} - The sender's display name
  # - {{company_name}} - The company name if known
  # - {{current_status}} - The current application status
  #
  class StatusExtractionPrompt < LlmPrompt
    # Default prompt template for status extraction
    #
    # @return [String] Default prompt template
    def self.default_prompt_template
      <<~PROMPT
        Analyze the following email to determine if it indicates a change in application status.

        FROM: {{from_name}} <{{from_email}}>
        SUBJECT: {{subject}}
        COMPANY: {{company_name}}
        CURRENT APPLICATION STATUS: {{current_status}}

        EMAIL CONTENT:
        {{body}}

        Extract the following information and respond with a JSON object:

        {
          "status_change": {
            "type": "rejection|offer|withdrawal|ghosted|on_hold|no_change",
            "is_final": true/false,
            "effective_date": "ISO 8601 date if mentioned"
          },
          "rejection_details": {
            "reason": "The stated reason for rejection (position filled, other candidates, not a fit, etc.)",
            "stage_rejected_at": "Stage where rejection occurred if mentioned (screening, technical, final, etc.)",
            "is_generic": true/false (true if it's a generic rejection template),
            "door_open": true/false (true if they mention keeping in touch for future opportunities)
          },
          "offer_details": {
            "role_title": "Job title offered",
            "department": "Department/team",
            "start_date": "Proposed start date if mentioned",
            "response_deadline": "Deadline to respond to offer",
            "includes_compensation_info": true/false,
            "compensation_hints": "Any salary/benefits mentioned (do not extract exact numbers)",
            "next_steps": "What they need from the candidate (sign offer, complete background check, etc.)"
          },
          "feedback": {
            "has_feedback": true/false,
            "feedback_text": "Any feedback provided about the candidate",
            "is_constructive": true/false (true if actionable feedback is given)
          },
          "follow_up": {
            "should_follow_up": true/false,
            "follow_up_date": "Suggested follow-up date if mentioned",
            "contact_person": "Who to contact for questions",
            "contact_email": "Email to contact"
          },
          "sentiment": "positive|negative|neutral|mixed",
          "confidence_score": 0.0 to 1.0
        }

        Guidelines for status_change.type:
        - "rejection" - Clear indication the application/interview process is ending negatively
        - "offer" - Explicit job offer being extended
        - "withdrawal" - Company withdrawing the position/process
        - "ghosted" - This email indicates extended silence or ghosting
        - "on_hold" - Position/process is paused but not ended
        - "no_change" - Email doesn't indicate a status change (follow-up, scheduling, etc.)

        Guidelines for rejection detection:
        - Look for: "regret to inform", "not moving forward", "decided to go with other candidates"
        - Check if it's a per-round rejection (fail one round) vs full application rejection
        - is_generic = true for templated rejections with no personalization
        - door_open = true if they mention "keep your resume on file" or "future opportunities"

        Guidelines for offer detection:
        - Must be an actual job offer, not just positive feedback
        - Look for: "pleased to offer", "extend an offer", "offer letter", "congratulations"
        - Note any deadlines for responding to the offer

        Use null for any field where information is not clearly available.
        Respond ONLY with the JSON object, no additional text or markdown.
      PROMPT
    end

    # Default system prompt for status extraction
    #
    # @return [String]
    def self.default_system_prompt
      <<~PROMPT
        You are an expert at analyzing job application emails to detect status changes.
        Your goal is to:
        - Determine if the email indicates a rejection, offer, or other status change
        - Extract relevant details about the change
        - Identify any feedback or next steps mentioned
        - Distinguish between per-round rejection and full application rejection

        Rules:
        - Return ONLY valid JSON, no markdown or commentary
        - Use null for missing information, never guess
        - Be conservative - only mark as rejection/offer if clearly indicated
        - "Congratulations on moving to the next round" is NOT an offer
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
        "company_name" => { "required" => false, "description" => "The company name if known" },
        "current_status" => { "required" => false, "description" => "The current application status" }
      }
    end
  end
end
