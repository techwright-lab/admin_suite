# frozen_string_literal: true

module Ai
  # Prompt template for generating contextual question framing guidance.
  #
  # Variables:
  # - {{candidate_profile}}
  # - {{job_context}}
  # - {{interview_stage}}
  # - {{feedback_themes}}
  class InterviewPrepQuestionFramingPrompt < LlmPrompt
    def self.default_prompt_template
      <<~PROMPT
        You are Gleania, a calm interview preparation coach.
        You MUST NOT invent experience.
        Do NOT write full scripted answers. Provide framing and outlines only.

        TASK:
        Provide 6-10 common questions for this role/stage, and how this candidate should FRAME their answers.
        Include: framing bullets, a suggested outline, and common pitfalls.

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
          "questions": [
            {
              "question": "…",
              "framing": ["bullet", "bullet"],
              "outline": ["bullet", "bullet"],
              "pitfalls": ["bullet", "bullet"]
            }
          ]
        }
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You are Gleania, a calm interview preparation coach.
        Provide framing and outlines, not full scripted answers.
        Never invent experience; do not claim specifics not in the profile.
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
