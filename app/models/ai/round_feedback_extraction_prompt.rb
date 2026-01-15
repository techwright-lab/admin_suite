# frozen_string_literal: true

module Ai
  # Prompt template for extracting interview round feedback from emails
  #
  # Used by Signals::RoundFeedbackProcessor to extract pass/fail results
  # and detailed feedback from per-round feedback emails.
  #
  # Variables:
  # - {{subject}} - The email subject line
  # - {{body}} - The email body content
  # - {{from_email}} - The sender's email address
  # - {{from_name}} - The sender's display name
  # - {{company_name}} - The company name if known
  # - {{recent_rounds}} - JSON array of recent interview rounds for context
  #
  class RoundFeedbackExtractionPrompt < LlmPrompt
    # Default prompt template for round feedback extraction
    #
    # @return [String] Default prompt template
    def self.default_prompt_template
      <<~PROMPT
        Analyze the following email to extract interview round feedback/results.

        FROM: {{from_name}} <{{from_email}}>
        SUBJECT: {{subject}}
        COMPANY: {{company_name}}

        RECENT INTERVIEW ROUNDS (for context):
        {{recent_rounds}}

        EMAIL CONTENT:
        {{body}}

        Extract the following information and respond with a JSON object:

        {
          "result": "passed|failed|waitlisted|unknown",
          "round_context": {
            "stage_mentioned": "The stage/round name mentioned (e.g., 'technical round', 'phone screen', 'final interview')",
            "interviewer_mentioned": "Name of interviewer mentioned in feedback",
            "date_mentioned": "Date of the interview being discussed, if mentioned"
          },
          "feedback": {
            "has_detailed_feedback": true/false,
            "summary": "Brief summary of the feedback",
            "strengths": ["Array of things that went well"],
            "improvements": ["Array of areas to improve"],
            "full_feedback_text": "Complete feedback text if provided"
          },
          "next_steps": {
            "has_next_round": true/false,
            "next_round_type": "Type of next round (e.g., 'technical', 'hiring manager', 'onsite')",
            "next_round_hint": "Any hints about what the next round involves",
            "timeline_hint": "Any mention of timeline (e.g., 'next week', 'within a few days')"
          },
          "is_final_round_result": true/false,
          "sentiment": "positive|negative|neutral",
          "confidence_score": 0.0 to 1.0
        }

        Guidelines for result detection:
        - "passed" - Clear indication of moving forward: "congratulations", "pleased to inform", "moving to next round", "passed"
        - "failed" - Clear rejection for this round: "not moving forward", "decided not to proceed", "unfortunately"
        - "waitlisted" - On hold: "waitlist", "keep you in mind", "position on hold"
        - "unknown" - Cannot determine outcome from email content

        Guidelines for round matching:
        - Look for stage mentions like "technical interview", "phone screen", "hiring manager round"
        - Look for interviewer names mentioned in feedback
        - Look for date references to match with recent rounds

        Guidelines for feedback extraction:
        - Capture specific strengths mentioned (technical skills, communication, etc.)
        - Capture specific areas for improvement
        - If detailed feedback is provided, include the full text

        Guidelines for next steps:
        - Detect if there's a next round scheduled or mentioned
        - Identify what type of round comes next
        - Note any timeline information

        Use null for any field where information is not clearly available.
        Respond ONLY with the JSON object, no additional text or markdown.
      PROMPT
    end

    # Default system prompt for round feedback extraction
    #
    # @return [String]
    def self.default_system_prompt
      <<~PROMPT
        You are an expert at analyzing interview feedback emails.
        Your goal is to:
        - Determine if the candidate passed, failed, or is waitlisted for this round
        - Extract any specific feedback provided
        - Identify what the next steps are
        - Match the feedback to a specific interview round if possible

        Rules:
        - Return ONLY valid JSON, no markdown or commentary
        - Use null for missing information, never guess
        - Be careful to distinguish between per-round rejection and full application rejection
        - "Passed" means moving to next round, not necessarily getting the job
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
        "recent_rounds" => { "required" => false, "description" => "JSON array of recent interview rounds" }
      }
    end
  end
end
