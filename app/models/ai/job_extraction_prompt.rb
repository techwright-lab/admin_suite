# frozen_string_literal: true

module Ai
  # Prompt template for extracting job listing data from HTML
  #
  # Used by Scraping::AiJobExtractorService to extract structured job data
  # from scraped HTML content.
  #
  # Variables:
  # - {{url}} - The job listing URL
  # - {{html_content}} - The cleaned HTML content
  #
  class JobExtractionPrompt < LlmPrompt
    # Default prompt template for job extraction
    #
    # @return [String] Default prompt template
    def self.default_prompt_template
      <<~PROMPT
        Extract the following information from this job listing HTML and return it as JSON:

        Required fields:
        - title: Job title
        - company: Company name (the organization posting the job)
        - company_domain: The industry/domain the company operates in (e.g., "FinTech", "SaaS", "Healthcare", "E-commerce", "EdTech", "AI/ML", "Cybersecurity", "Gaming", "Social Media", "Enterprise Software", "B2B", "B2C", "Marketplace", "Media/Entertainment", "Real Estate", "Travel", "Logistics", "Automotive", "CleanTech", "Biotech", "Other" - use null if unclear)
        - job_role: Job role/title (can be the same as title or a normalized version)
        - job_role_department: The department/function this role belongs to (one of: "Engineering", "Product", "Design", "Data Science", "DevOps/SRE", "Sales", "Marketing", "Customer Success", "Finance", "HR/People", "Legal", "Operations", "Executive", "Research", "QA/Testing", "Security", "IT", "Content", "Other")
        - job_board: The job board where the job listing was found (e.g. "LinkedIn", "Greenhouse", "Lever", "Indeed", "Glassdoor", "Workable", "Jobvite", "ICIMS", "SmartRecruiters", "BambooHR", "AshbyHQ", "Other")
        - description: Full job description (text only, no HTML)
        - requirements: Required qualifications and skills
        - responsibilities: Key responsibilities and duties
        - location: Office location or "Remote"
        - remote_type: one of "on_site", "hybrid", or "remote"

        Optional fields (use null if not found):
        - about_company: A concise "About the company" section (mission/product context)
        - company_culture: Company values/culture section (how they work, principles, DEI, etc.)
        - salary_min: Minimum salary as number
        - salary_max: Maximum salary as number
        - salary_currency: Currency code (e.g., "USD", "EUR")
        - equity_info: Stock options or equity details
        - benefits: Benefits package description
        - perks: Additional perks and amenities
        - custom_sections: Any additional structured data as a JSON object

        Also provide:
        - confidence_score: Your confidence in the extraction accuracy (0.0 to 1.0)
        - notes: Any extraction challenges or uncertainties

        Job Listing URL: {{url}}

        HTML Content:
        {{html_content}}

        Return only valid JSON with no additional commentary.
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You are an expert at extracting structured job listing data from HTML. You are given a job listing URL and the HTML content of the job listing. You need to extract the structured data from the HTML content.
      PROMPT
    end

    # Returns the expected variables for this prompt type
    #
    # @return [Hash] Variable definitions
    def self.default_variables
      {
        "url" => { "required" => true, "description" => "The job listing URL" },
        "html_content" => { "required" => true, "description" => "The cleaned HTML content" }
      }
    end
  end
end
