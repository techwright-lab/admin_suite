# frozen_string_literal: true

module Ai
  # Prompt template for extracting job opportunity data from recruiter emails
  #
  # Used by Opportunities::ExtractionService to extract structured opportunity
  # data from email content (subject + body).
  #
  # Variables:
  # - {{subject}} - The email subject line
  # - {{body}} - The email body content
  #
  class EmailExtractionPrompt < LlmPrompt
    # Default prompt template for email extraction
    #
    # @return [String] Default prompt template
    def self.default_prompt_template
      <<~PROMPT
        Analyze the following email content and extract structured information about the job opportunity.
        The email may be a direct message from a recruiter, a forwarded or a direct message from LinkedIn, or a referral.

        EMAIL SUBJECT: {{subject}}

        EMAIL CONTENT:
        {{body}}

        Extract the following information and respond with a JSON object:

        {
          "company_name": "The company with the job opening (not the recruiting agency unless they are the employer)",
          "company_domain": "The industry/domain the company operates in (e.g., 'FinTech', 'SaaS', 'Healthcare', 'E-commerce', 'EdTech', 'AI/ML', 'Cybersecurity', 'Enterprise Software', 'B2B', 'B2C', etc. - use null if unclear)",
          "job_role_title": "The job title or role being offered",
          "job_role_department": "The department/function this role belongs to (one of: 'Engineering', 'Product', 'Design', 'Data Science', 'DevOps/SRE', 'Sales', 'Marketing', 'Customer Success', 'Finance', 'HR/People', 'Legal', 'Operations', 'Executive', 'Research', 'QA/Testing', 'Security', 'IT', 'Content', 'Other')",
          "job_url": "URL to the job listing or application page (if found in the email)",
          "all_links": [
            {"url": "...", "type": "job_posting|company_website|calendar|linkedin|other", "description": "brief description"}
          ],
          "recruiter_info": {
            "name": "Recruiter's name",
            "title": "Recruiter's job title",
            "company": "Recruiting company or agency name"
          },
          "key_details": "A brief summary of important details like: location, remote/hybrid/onsite, salary range, tech stack, company stage, team size, etc.",
          "is_forwarded": true/false,
          "original_source": "linkedin|email|referral|other",
          "confidence_score": 0.0 to 1.0, # Confidence score for the overall extraction
          "potential_opportunity": true/false, # Whether this is a potential opportunity or just a generic/newletter type email
          "potential_opportunity_confidence_score": 0.0 to 1.0, # Confidence score for the potential opportunity
          "potential_opportunity_confidence_reasoning": "The reasoning for why this is a potential opportunity or not, if potential_opportunity is false, this should be null"
        }

        Guidelines:
        - If information is not clearly stated, use null instead of guessing
        - For job_url, only include URLs that lead to job listings or application pages
        - Distinguish between the hiring company and any recruiting agency
        - Look for LinkedIn message indicators, forwarded email markers
        - Extract all relevant links even if they're not the main job posting
        - confidence_score should reflect how confident you are in the extracted information

        Respond ONLY with the JSON object, no additional text.
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You are an expert at extracting structured job opportunity information from recruiter emails.
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
        "subject" => { "required" => true, "description" => "The email subject line" },
        "body" => { "required" => true, "description" => "The email body content" }
      }
    end
  end
end
