# frozen_string_literal: true

module Ai
  # Prompt template for extracting skills from resume/CV text
  #
  # Used by Resumes::AiSkillExtractorService to extract structured skill data
  # from parsed resume text.
  #
  # Variables:
  # - {{resume_text}} - The parsed resume text content
  #
  class ResumeSkillExtractionPrompt < LlmPrompt
    # Default prompt template for resume skill extraction
    #
    # @return [String] Default prompt template
    def self.default_prompt_template
      <<~PROMPT
        Analyze the following resume/CV text and extract all professional skills, competencies, work history, and areas of expertise.

        For each skill identified, provide:
        1. **name**: The skill name (use common industry terminology, e.g., "Ruby on Rails" not "RoR")
        2. **category**: One of: Backend, Frontend, Fullstack, Infrastructure, DevOps, Data, Mobile, Leadership, Communication, ProjectManagement, Design, Security, AI/ML, Other
        3. **proficiency**: A level from 1-5 based on evidence in the resume:
           - 5 = Expert (extensive experience, leadership, teaching others)
           - 4 = Advanced (significant professional experience, complex projects)
           - 3 = Intermediate (solid working knowledge, multiple projects)
           - 2 = Elementary (some experience, basic projects)
           - 1 = Beginner (mentioned but limited evidence)
        4. **confidence**: Your confidence in this assessment (0.0-1.0)
        5. **evidence**: A brief quote or description from the resume supporting this skill
        6. **years**: Estimated years of experience if determinable (null if unclear)

        Also extract work history:
        - For each job/position, provide: **company** (full company name), **role** (job title), **duration** (years or months)
        - Order from most recent to oldest

        Also provide:
        - A brief **summary** of the candidate's overall profile (2-3 sentences)
        - An **overall_confidence** score for the entire extraction (0.0-1.0)
        - **strengths**: Top 3-5 key strengths based on the resume
        - **domains**: Primary professional domains/industries
        - **resume_date**: Estimated date when this resume was last updated (YYYY-MM-DD format, or null if unknown). Look for document dates, "updated" mentions, or infer from the most recent job end date.
        - **resume_date_confidence**: How confident you are in the resume date ("high", "medium", "low", or "unknown")
        - **resume_date_source**: How you determined the date ("document_metadata", "explicit_mention", "most_recent_job", or "unknown")

        Respond with valid JSON only, no markdown or explanation:

        {
          "skills": [
            {
              "name": "Ruby on Rails",
              "category": "Backend",
              "proficiency": 4,
              "confidence": 0.9,
              "evidence": "5+ years building Rails applications at scale",
              "years": 5
            }
          ],
          "work_history": [
            {
              "company": "Acme Corp",
              "role": "Senior Software Engineer",
              "duration": "3 years"
            }
          ],
          "summary": "Senior backend engineer with strong Ruby and distributed systems experience...",
          "overall_confidence": 0.85,
          "strengths": ["Backend Development", "System Design", "Team Leadership"],
          "domains": ["FinTech", "SaaS"],
          "resume_date": "2024-06-15",
          "resume_date_confidence": "medium",
          "resume_date_source": "most_recent_job"
        }

        RESUME TEXT:
        {{resume_text}}
      PROMPT
    end

    # Returns the expected variables for this prompt type
    #
    # @return [Hash] Variable definitions
    def self.default_variables
      {
        "resume_text" => { "required" => true, "description" => "The parsed resume text content" }
      }
    end
  end
end
