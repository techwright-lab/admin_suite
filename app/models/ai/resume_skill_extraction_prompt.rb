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
        Analyze the following resume/Curriculum Vitae text and extract all professional skills, competencies, work history, and areas of expertise.

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
        - For each job/position, provide: **company** (full company name), **company_domain** (the industry/domain the company operates in, e.g., "FinTech", "SaaS", "Healthcare", "E-commerce", "EdTech", "AI/ML", "Cybersecurity", "Enterprise Software", "B2B", "B2C", etc. - use null if unclear), **role** (job title), **role_department** (the department/function this role belongs to, one of: "Engineering", "Product", "Design", "Data Science", "DevOps/SRE", "Sales", "Marketing", "Customer Success", "Finance", "HR/People", "Legal", "Operations", "Executive", "Research", "QA/Testing", "Security", "IT", "Content", "Other"), **duration** (years or months), **highlight** (a brief description of the job's most significant accomplishment), **start_date** (the date the job started), **end_date** (the date the job ended or null if still current), **current** (true if the job is still current, false if it has ended), **responsibilities** (an array of responsibilities the candidate had in the job), **skills_used** (an array of skills the candidate used in the job)
        - For each skill used, provide: **name** (the skill name), **confidence** (your confidence in this assessment of the skill's usage, 0.0-1.0), **evidence** (a brief quote or description from the resume supporting this skill usage)
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
              "company_domain": "FinTech",
              "role": "Senior Software Engineer",
              "role_department": "Engineering",
              "duration": "3 years",
              "highlight": "Built scalable backend infrastructure for a fintech startup",
              "start_date": "2021-01-01",
              "end_date": "2024-01-01",
              "current": false,
              "responsibilities": [
                "Developed and maintained scalable backend infrastructure",
                "Built RESTful APIs for internal tools and external integrations",
                "Optimized database queries and implemented caching strategies",
                "Collaborated with frontend and mobile teams to ensure seamless integration"
              ],
              "skills_used": [
                {
                  "name": "Ruby on Rails",
                  "confidence": 0.9,
                  "evidence": "5+ years building Rails applications at scale"
                }
              ]
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

    def self.default_system_prompt
      <<~PROMPT
        You are an expert at extracting skills, strengths, domains, competencies, work history, and areas of expertise from unstructured text extracted from a resume or Curriculum Vitae, then converting it into structured json response.
        Your goal is to return only valid JSON. Do not guess missing values; use null.
        Do not include markdown or extra commentary.
        Do not include any other text or formatting.
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
