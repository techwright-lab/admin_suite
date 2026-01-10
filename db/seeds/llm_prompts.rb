# frozen_string_literal: true

# Seed LLM prompts with default templates for each operation type

puts "Creating LLM Prompts..."

# Create Job Extraction Prompt
job_prompt = Ai::JobExtractionPrompt.find_or_create_by!(name: "Job Extraction - Default") do |prompt|
  prompt.description = "Default prompt template for extracting job listing data from HTML"
  prompt.prompt_template = Ai::JobExtractionPrompt.default_prompt_template
  prompt.variables = Ai::JobExtractionPrompt.default_variables
  prompt.system_prompt = Ai::JobExtractionPrompt.default_system_prompt
  prompt.version = 1
  prompt.active = true
end
puts "  - Created: #{job_prompt.name} (active: #{job_prompt.active})"

# Create Email Extraction Prompt
email_prompt = Ai::EmailExtractionPrompt.find_or_create_by!(name: "Email Extraction - Default") do |prompt|
  prompt.description = "Default prompt template for extracting opportunity data from recruiter emails"
  prompt.prompt_template = Ai::EmailExtractionPrompt.default_prompt_template
  prompt.variables = Ai::EmailExtractionPrompt.default_variables
  prompt.system_prompt = Ai::EmailExtractionPrompt.default_system_prompt
  prompt.version = 1
  prompt.active = true
end
puts "  - Created: #{email_prompt.name} (active: #{email_prompt.active})"

# Create Resume Skill Extraction Prompt
resume_prompt = Ai::ResumeSkillExtractionPrompt.find_or_create_by!(name: "Resume Skill Extraction - Default") do |prompt|
  prompt.description = "Default prompt template for extracting skills from resume text"
  prompt.prompt_template = Ai::ResumeSkillExtractionPrompt.default_prompt_template
  prompt.variables = Ai::ResumeSkillExtractionPrompt.default_variables
  prompt.system_prompt = Ai::ResumeSkillExtractionPrompt.default_system_prompt
  prompt.version = 1
  prompt.active = true
end
puts "  - Created: #{resume_prompt.name} (active: #{resume_prompt.active})"

# Create Assistant System Prompt
assistant_system_prompt = Ai::AssistantSystemPrompt.find_or_create_by!(name: "Assistant System Prompt - Default") do |prompt|
  prompt.description = "Default system prompt for the in-app assistant (Gleania). Controls tone, safety rules, and response formatting."
  prompt.prompt_template = Ai::AssistantSystemPrompt.default_prompt_template
  prompt.variables = Ai::AssistantSystemPrompt.default_variables
  prompt.system_prompt = Ai::AssistantSystemPrompt.default_system_prompt
  prompt.version = 1
  prompt.active = true
end
puts "  - Created: #{assistant_system_prompt.name} (active: #{assistant_system_prompt.active})"

# Create Assistant Thread Summary Prompt
thread_summary_prompt = Ai::AssistantThreadSummaryPrompt.find_or_create_by!(name: "Assistant Thread Summary - Default") do |prompt|
  prompt.description = "Prompt template for summarizing assistant chat threads to preserve context across long conversations."
  prompt.prompt_template = Ai::AssistantThreadSummaryPrompt.default_prompt_template
  prompt.variables = Ai::AssistantThreadSummaryPrompt.default_variables
  prompt.system_prompt = Ai::AssistantThreadSummaryPrompt.default_system_prompt
  prompt.version = 1
  prompt.active = true
end
puts "  - Created: #{thread_summary_prompt.name} (active: #{thread_summary_prompt.active})"

# Create Assistant Memory Proposal Prompt
memory_proposal_prompt = Ai::AssistantMemoryProposalPrompt.find_or_create_by!(name: "Assistant Memory Proposal - Default") do |prompt|
  prompt.description = "Prompt template for extracting durable user preferences, goals, and constraints to remember across chats."
  prompt.prompt_template = Ai::AssistantMemoryProposalPrompt.default_prompt_template
  prompt.variables = Ai::AssistantMemoryProposalPrompt.default_variables
  prompt.system_prompt = Ai::AssistantMemoryProposalPrompt.default_system_prompt
  prompt.version = 1
  prompt.active = true
end


puts "  - Created: #{memory_proposal_prompt.name} (active: #{memory_proposal_prompt.active})"

puts "LLM Prompts created: #{Ai::LlmPrompt.count} total"
