# frozen_string_literal: true

module Ai
  # Prompt template for post-processing job content into structured fields + Markdown.
  #
  # Variables:
  # - {{url}} - The job listing URL
  # - {{html_content}} - The job posting content (HTML or text)
  class JobPostprocessPrompt < LlmPrompt
    def self.default_prompt_template
      <<~PROMPT
        Given the job posting content below, extract missing structured information and produce a clean Markdown version suitable for display.

        IMPORTANT:
        - Return ONLY valid JSON (no code fences).
        - job_markdown MUST be valid, well-formatted Markdown.
        - DO NOT include HTML tags (no <strong>, <p>, etc). Use Markdown instead (**bold**, *italic*).
        - Only extract what is present in the content. If something isn't present, return null/[] accordingly.

        MARKDOWN FORMAT for job_markdown:
        - Use ## for main sections (e.g., ## About the Role, ## Responsibilities, ## Requirements, ## Benefits)
        - Use ### for subsections
        - Use - for bullet lists (not *)
        - Use **text** for bold emphasis
        - Use *text* for italic emphasis
        - Preserve the logical structure of the original posting
        - Include all content: about company, role description, responsibilities, requirements, benefits, etc.

        Return JSON with this schema:
        {
          "job_markdown": String,
          "compensation_text": String|null,
          "salary_min": Number|null,
          "salary_max": Number|null,
          "salary_currency": String|null,
          "interview_process": String|null,
          "responsibilities_bullets": [String],
          "requirements_bullets": [String],
          "benefits_bullets": [String],
          "perks_bullets": [String],
          "confidence_score": Number
        }

        Job URL: {{url}}

        Job Content:
        {{html_content}}
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You are an expert at extracting structured job posting information and producing clean Markdown for display.

        For job_markdown, produce clean, well-formatted Markdown that preserves the job posting's structure. Use consistent heading levels (## for sections, ### for subsections) and bullet lists (- item) for lists. Never include HTML tags in the markdown output.
      PROMPT
    end

    def self.default_variables
      {
        "url" => { "required" => true, "description" => "The job listing URL" },
        "html_content" => { "required" => true, "description" => "The job posting content (HTML or text)" }
      }
    end
  end
end
