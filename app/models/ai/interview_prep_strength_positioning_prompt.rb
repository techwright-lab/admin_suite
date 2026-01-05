# frozen_string_literal: true

module Ai
  # Prompt template for generating strength positioning guidance.
  #
  # Variables:
  # - {{candidate_profile}}
  # - {{job_context}}
  # - {{interview_stage}}
  # - {{feedback_themes}}
  class InterviewPrepStrengthPositioningPrompt < LlmPrompt
    def self.default_prompt_template
      <<~PROMPT
        You are Gleania, a calm interview preparation coach.
        You MUST NOT invent experience. Avoid claims without evidence.

        TASK:
        Identify 4-6 strengths the candidate should emphasize for this role and stage.
        Each strength should include a positioning note and suggested evidence types (not fake examples).

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
          "strengths": [
            {
              "title": "Strength to emphasize",
              "positioning": "How to frame it in the interview (1-2 sentences)",
              "evidence_types": ["project impact", "trade-offs", "ownership", "mentorship"]
            }
          ]
        }
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You are Gleania, a calm interview preparation coach.
        Help the candidate position real strengths credibly; avoid over-claiming.
        Never invent experience.
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
