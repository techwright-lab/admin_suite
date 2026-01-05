# frozen_string_literal: true

class SeedInterviewPrepLlmPrompts < ActiveRecord::Migration[8.1]
  # Minimal model wrapper to avoid relying on app models during migrations.
  class LlmPrompt < ActiveRecord::Base
    self.table_name = "llm_prompts"
    self.inheritance_column = :_type_disabled
  end

  def up
    seed_if_missing!(
      type: "Ai::InterviewPrepMatchPrompt",
      name: "Interview Prep - Match Analysis (Default)",
      description: "Seeded prompt for qualitative match analysis (Strong/Partial/Stretch).",
      version: 1,
      active: true,
      system_prompt: <<~SYSTEM,
        You are Gleania, a calm, practical interview preparation coach.
        Be concise, accurate, and grounded in the provided data.
        Never invent experience; if unknown, say so.
      SYSTEM
      variables: {
        "candidate_profile" => { "required" => true, "description" => "Candidate profile JSON" },
        "job_context" => { "required" => true, "description" => "Job context JSON" },
        "interview_stage" => { "required" => true, "description" => "Interview stage label" },
        "feedback_themes" => { "required" => false, "description" => "Feedback themes JSON" }
      },
      prompt_template: <<~PROMPT
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
    )

    seed_if_missing!(
      type: "Ai::InterviewPrepFocusAreasPrompt",
      name: "Interview Prep - Focus Areas (Default)",
      description: "Seeded prompt for actionable focus areas (why, how, experiences).",
      version: 1,
      active: true,
      system_prompt: <<~SYSTEM,
        You are Gleania, a calm, practical interview preparation coach.
        Focus on actionable preparation guidance. Do not invent experience.
      SYSTEM
      variables: {
        "candidate_profile" => { "required" => true, "description" => "Candidate profile JSON" },
        "job_context" => { "required" => true, "description" => "Job context JSON" },
        "interview_stage" => { "required" => true, "description" => "Interview stage label" },
        "feedback_themes" => { "required" => false, "description" => "Feedback themes JSON" }
      },
      prompt_template: <<~PROMPT
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
    )

    seed_if_missing!(
      type: "Ai::InterviewPrepQuestionFramingPrompt",
      name: "Interview Prep - Question Framing (Default)",
      description: "Seeded prompt for contextual question framing (no scripted answers).",
      version: 1,
      active: true,
      system_prompt: <<~SYSTEM,
        You are Gleania, a calm interview preparation coach.
        Provide framing and outlines, not full scripted answers.
        Never invent experience; do not claim specifics not in the profile.
      SYSTEM
      variables: {
        "candidate_profile" => { "required" => true, "description" => "Candidate profile JSON" },
        "job_context" => { "required" => true, "description" => "Job context JSON" },
        "interview_stage" => { "required" => true, "description" => "Interview stage label" },
        "feedback_themes" => { "required" => false, "description" => "Feedback themes JSON" }
      },
      prompt_template: <<~PROMPT
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
    )

    seed_if_missing!(
      type: "Ai::InterviewPrepStrengthPositioningPrompt",
      name: "Interview Prep - Strength Positioning (Default)",
      description: "Seeded prompt for credible strength positioning (no over-claiming).",
      version: 1,
      active: true,
      system_prompt: <<~SYSTEM,
        You are Gleania, a calm interview preparation coach.
        Help the candidate position real strengths credibly; avoid over-claiming.
        Never invent experience.
      SYSTEM
      variables: {
        "candidate_profile" => { "required" => true, "description" => "Candidate profile JSON" },
        "job_context" => { "required" => true, "description" => "Job context JSON" },
        "interview_stage" => { "required" => true, "description" => "Interview stage label" },
        "feedback_themes" => { "required" => false, "description" => "Feedback themes JSON" }
      },
      prompt_template: <<~PROMPT
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
    )

    backfill_email_extraction_system_prompt!
  end

  def down
    LlmPrompt.where(type: "Ai::InterviewPrepMatchPrompt", name: "Interview Prep - Match Analysis (Default)").delete_all
    LlmPrompt.where(type: "Ai::InterviewPrepFocusAreasPrompt", name: "Interview Prep - Focus Areas (Default)").delete_all
    LlmPrompt.where(type: "Ai::InterviewPrepQuestionFramingPrompt", name: "Interview Prep - Question Framing (Default)").delete_all
    LlmPrompt.where(type: "Ai::InterviewPrepStrengthPositioningPrompt", name: "Interview Prep - Strength Positioning (Default)").delete_all
    # Do not revert email extraction system_prompt (could have been edited intentionally).
  end

  private

  def seed_if_missing!(type:, name:, description:, version:, active:, system_prompt:, variables:, prompt_template:)
    return if LlmPrompt.where(type: type).exists?

    LlmPrompt.create!(
      type: type,
      name: name,
      description: description,
      version: version,
      active: active,
      system_prompt: system_prompt.to_s.strip,
      variables: variables,
      prompt_template: prompt_template
    )
  end

  def backfill_email_extraction_system_prompt!
    prompt = LlmPrompt.where(type: "Ai::EmailExtractionPrompt").order(active: :desc, version: :desc).first
    return unless prompt
    return if prompt.system_prompt.present?

    prompt.update!(
      system_prompt: <<~SYSTEM.strip
        You are an expert at extracting structured job opportunity information from recruiter emails.
        Return only valid JSON. Do not guess missing values; use null.
      SYSTEM
    )
  end
end
