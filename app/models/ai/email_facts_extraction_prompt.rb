# frozen_string_literal: true

module Ai
  # Prompt template for extracting EmailFacts (unified workflow facts) from emails.
  #
  # Used by Signals::Facts::EmailFactsExtractor.
  #
  # Variables:
  # - {{subject}}
  # - {{body}}
  # - {{from_email}}
  # - {{from_name}}
  # - {{email_type}} (legacy classifier hint, optional)
  # - {{application_snapshot}} (JSON string, optional)
  class EmailFactsExtractionPrompt < LlmPrompt
    def self.default_prompt_template
      <<~PROMPT
        You are extracting workflow facts from a recruiting/interview email.
        You MUST NOT guess. If information is not explicitly present, use null/false/empty.

        FROM: {{from_name}} <{{from_email}}>
        SUBJECT: {{subject}}
        LEGACY_EMAIL_TYPE_HINT: {{email_type}}

        APPLICATION SNAPSHOT (may be null):
        {{application_snapshot}}

        EMAIL BODY (canonicalized):
        {{body}}

        Return ONLY valid JSON matching this shape:

        {
          "extraction": { "provider": null, "model": null, "confidence": 0.0, "warnings": [] },
          "classification": { "kind": "scheduling|interview_invite|round_feedback|status_update|application_confirmation|recruiter_outreach|interview_assessment|other|unknown", "confidence": 0.0, "evidence": ["..."] },
          "entities": {
            "company": { "name": null, "website": null },
            "recruiter": { "name": null, "email": null, "title": null },
            "job": { "title": null, "department": null, "location": null, "url": null }
          },
          "action_links": [{ "url": "...", "action_label": "...", "priority": 1 }],
          "key_insights": null,
          "is_forwarded": false,
          "scheduling": {
            "is_scheduling_related": false,
            "scheduled_at": null,
            "timezone_hint": null,
            "duration_minutes": 0,
            "stage": null,
            "round_type": null,
            "stage_name": null,
            "interviewer_name": null,
            "interviewer_role": null,
            "video_link": null,
            "phone_number": null,
            "location": null,
            "is_rescheduled": false,
            "is_cancelled": false,
            "original_scheduled_at": null,
            "evidence": []
          },
          "round_feedback": {
            "has_round_feedback": false,
            "result": null,
            "stage_mentioned": null,
            "round_type": null,
            "interviewer_mentioned": null,
            "date_mentioned": null,
            "feedback": { "has_detailed_feedback": false, "summary": null, "strengths": [], "improvements": [], "full_feedback_text": null },
            "next_steps": { "has_next_round": false, "next_round_type": null, "next_round_hint": null, "timeline_hint": null },
            "evidence": []
          },
          "status_change": {
            "has_status_change": false,
            "type": "rejection|offer|withdrawal|ghosted|on_hold|no_change|null",
            "is_final": null,
            "effective_date": null,
            "rejection_details": { "reason": null, "stage_rejected_at": null, "is_generic": false, "door_open": false },
            "offer_details": { "role_title": null, "department": null, "start_date": null, "response_deadline": null, "includes_compensation_info": false, "compensation_hints": null, "next_steps": null },
            "feedback": { "has_feedback": false, "feedback_text": null, "is_constructive": false },
            "evidence": []
          }
        }

        Rules:
        - Output ONLY JSON, no markdown, no commentary.
        - Every evidence string MUST be a direct substring from the email body or subject.
        - Include only up to 20 action_links. Prioritize schedule/join/apply links.
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You extract structured facts for an email-driven interview workflow.
        Be conservative. Do not infer hidden state. Do not guess.
        Return only valid JSON.
      PROMPT
    end

    def self.default_variables
      {
        "subject" => { "required" => true },
        "body" => { "required" => true },
        "from_email" => { "required" => false },
        "from_name" => { "required" => false },
        "email_type" => { "required" => false },
        "application_snapshot" => { "required" => false }
      }
    end
  end
end
