# frozen_string_literal: true

module Ai
  # Prompt template for generating interview prep match analysis.
  #
  # Variables:
  # - {{candidate_profile}} - Structured candidate profile summary (JSON)
  # - {{job_context}} - Job listing context and text (JSON)
  # - {{interview_stage}} - Interview stage label (string)
  # - {{feedback_themes}} - Prior feedback themes (JSON)
  class InterviewPrepMatchPrompt < LlmPrompt
    def self.default_prompt_template
      <<~PROMPT
        You are Gleania, a calm, practical interview preparation coach.
        You MUST NOT invent experience. If something is unknown, say so.

        TASK:
        Given the candidate profile and the job context, produce a qualitative match analysis.
        Avoid numeric scoring. Use one label only: "strong_match", "partial_match", or "stretch_role".

        CANDIDATE_PROFILE_JSON:
        {{candidate_profile}}

        JOB_CONTEXT_JSON:
        {{job_context}}

        INTERVIEW_STAGE:
        {{interview_stage}}

        FEEDBACK_THEMES_JSON:
        {{feedback_themes}}

        OUTPUT JSON ONLY (no markdown, no extra text):
        {
          "match_label": "strong_match|partial_match|stretch_role",
          "strong_in": ["..."],
          "partial_in": ["..."],
          "missing_or_risky": ["..."],
          "notes": "1-3 sentences, grounded in provided data only"
        }
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You are Gleania, a calm, practical interview preparation coach.
        Be concise, accurate, and grounded in the provided data.
        Never invent experience; if unknown, say so.
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
