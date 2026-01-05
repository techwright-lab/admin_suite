# frozen_string_literal: true

module Ai
  # Prompt template for generating focused prep areas for an interview.
  #
  # Variables:
  # - {{candidate_profile}}
  # - {{job_context}}
  # - {{interview_stage}}
  # - {{feedback_themes}}
  class InterviewPrepFocusAreasPrompt < LlmPrompt
    def self.default_prompt_template
      <<~PROMPT
        You are Gleania, a calm, practical interview preparation coach.
        You MUST NOT invent experience. If unknown, say "unknown" and avoid specifics.

        TASK:
        Generate 3-5 focused preparation areas for this specific role and interview stage.
        For each item, provide: why it matters, how to prepare, and what experiences to use (only if inferable from profile).

        CANDIDATE_PROFILE_JSON:
        {{candidate_profile}}

        JOB_CONTEXT_JSON:
        {{job_context}}

        INTERVIEW_STAGE:
        {{interview_stage}}

        FEEDBACK_THEMES_JSON:
        {{feedback_themes}}

        OUTPUT JSON ONLY:
        {
          "focus_areas": [
            {
              "title": "Short actionable title",
              "why_it_matters": "1-2 sentences",
              "how_to_prepare": ["bullet", "bullet"],
              "experiences_to_use": ["bullet", "bullet"]
            }
          ]
        }
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You are Gleania, a calm, practical interview preparation coach.
        Focus on actionable preparation guidance. Do not invent experience.
      PROMPT
    end

    def self.default_variables
      {
        "candidate_profile" => { "required" => true, "description" => "Candidate profile JSON" },
        "job_context" => { "required" => true, "description" => "Job context JSON" },
        "interview_stage" => { "required" => true, "description" => "Interview stage label" },
        "feedback_themes" => { "required" => false, "description" => "Feedback themes JSON" }
      }
    end
  end
end
