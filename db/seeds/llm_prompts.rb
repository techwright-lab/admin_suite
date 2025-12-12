# frozen_string_literal: true

# Seed LLM prompts with default templates for each operation type

puts "Creating LLM Prompts..."

# Create Job Extraction Prompt
job_prompt = Ai::JobExtractionPrompt.find_or_create_by!(name: "Job Extraction - Default") do |prompt|
  prompt.description = "Default prompt template for extracting job listing data from HTML"
  prompt.prompt_template = Ai::JobExtractionPrompt.default_prompt_template
  prompt.variables = Ai::JobExtractionPrompt.default_variables
  prompt.version = 1
  prompt.active = true
end
puts "  - Created: #{job_prompt.name} (active: #{job_prompt.active})"

# Create Email Extraction Prompt
email_prompt = Ai::EmailExtractionPrompt.find_or_create_by!(name: "Email Extraction - Default") do |prompt|
  prompt.description = "Default prompt template for extracting opportunity data from recruiter emails"
  prompt.prompt_template = Ai::EmailExtractionPrompt.default_prompt_template
  prompt.variables = Ai::EmailExtractionPrompt.default_variables
  prompt.version = 1
  prompt.active = true
end
puts "  - Created: #{email_prompt.name} (active: #{email_prompt.active})"

# Create Resume Skill Extraction Prompt
resume_prompt = Ai::ResumeSkillExtractionPrompt.find_or_create_by!(name: "Resume Skill Extraction - Default") do |prompt|
  prompt.description = "Default prompt template for extracting skills from resume text"
  prompt.prompt_template = Ai::ResumeSkillExtractionPrompt.default_prompt_template
  prompt.variables = Ai::ResumeSkillExtractionPrompt.default_variables
  prompt.version = 1
  prompt.active = true
end
puts "  - Created: #{resume_prompt.name} (active: #{resume_prompt.active})"

puts "LLM Prompts created: #{Ai::LlmPrompt.count} total"




