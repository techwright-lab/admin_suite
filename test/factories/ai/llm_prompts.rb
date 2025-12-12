# frozen_string_literal: true

FactoryBot.define do
  # Base LlmPrompt factory
  factory :llm_prompt, class: "Ai::LlmPrompt" do
    sequence(:name) { |n| "Test Prompt #{n}" }
    description { "A test prompt for testing" }
    prompt_template { "Test template with {{variable}}" }
    variables { { "variable" => { "required" => true, "description" => "A test variable" } } }
    version { 1 }
    active { false }

    trait :active do
      active { true }
    end
  end

  # Job Extraction Prompt
  factory :job_extraction_prompt, class: "Ai::JobExtractionPrompt" do
    sequence(:name) { |n| "Job Extraction Prompt #{n}" }
    description { "Prompt for extracting job data from HTML" }
    prompt_template { Ai::JobExtractionPrompt.default_prompt_template }
    variables { Ai::JobExtractionPrompt.default_variables }
    version { 1 }
    active { false }

    trait :active do
      active { true }
    end
  end

  # Email Extraction Prompt
  factory :email_extraction_prompt, class: "Ai::EmailExtractionPrompt" do
    sequence(:name) { |n| "Email Extraction Prompt #{n}" }
    description { "Prompt for extracting opportunity data from emails" }
    prompt_template { Ai::EmailExtractionPrompt.default_prompt_template }
    variables { Ai::EmailExtractionPrompt.default_variables }
    version { 1 }
    active { false }

    trait :active do
      active { true }
    end
  end

  # Resume Skill Extraction Prompt
  factory :resume_skill_extraction_prompt, class: "Ai::ResumeSkillExtractionPrompt" do
    sequence(:name) { |n| "Resume Skill Extraction Prompt #{n}" }
    description { "Prompt for extracting skills from resume text" }
    prompt_template { Ai::ResumeSkillExtractionPrompt.default_prompt_template }
    variables { Ai::ResumeSkillExtractionPrompt.default_variables }
    version { 1 }
    active { false }

    trait :active do
      active { true }
    end
  end
end




