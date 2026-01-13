# frozen_string_literal: true

class AddAssistantToolsV2 < ActiveRecord::Migration[8.1]
  class AssistantTool < ActiveRecord::Base
    self.table_name = "assistant_tools"
  end

  def up
    now = Time.current

    tools = [
      # Target Domain Tools
      tool_def(
        tool_key: "list_target_domains",
        name: "List target domains",
        description: "List the user's target professional domains (e.g., FinTech, SaaS, Healthcare).",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::ListTargetDomainsTool",
        arg_schema: {
          type: "object",
          properties: {
            limit: { type: "number", description: "Maximum number of domains to return (1-100, default 50)" }
          }
        },
        timeout_ms: 5000
      ),
      tool_def(
        tool_key: "add_target_domain",
        name: "Add target domain",
        description: "Add one or more professional domains to the user's target domains list.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::AddTargetDomainTool",
        arg_schema: {
          type: "object",
          properties: {
            domain_id: { type: "number", description: "ID of an existing domain" },
            domain_name: { type: "string", description: "Name of the domain (will create if not found)" },
            priority: { type: "number", description: "Priority order (lower = higher priority)" },
            domains: {
              type: "array",
              description: "Array of domains to add in batch",
              items: {
                type: "object",
                properties: {
                  domain_id: { type: "number" },
                  domain_name: { type: "string" },
                  priority: { type: "number" }
                }
              }
            }
          }
        },
        timeout_ms: 8000
      ),
      tool_def(
        tool_key: "remove_target_domain",
        name: "Remove target domain",
        description: "Remove one or more domains from the user's target domains list.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::RemoveTargetDomainTool",
        arg_schema: {
          type: "object",
          properties: {
            domain_id: { type: "number" },
            domain_name: { type: "string" },
            domains: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  domain_id: { type: "number" },
                  domain_name: { type: "string" }
                }
              }
            }
          }
        },
        timeout_ms: 8000
      ),

      # Work History Tools
      tool_def(
        tool_key: "list_work_history",
        name: "List work history",
        description: "List the user's work history (companies, roles, dates, highlights, skills used).",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::ListWorkHistoryTool",
        arg_schema: {
          type: "object",
          properties: {
            limit: { type: "number", description: "Maximum number of experiences to return (1-50, default 20)" },
            include_skills: { type: "boolean", description: "Include skills used in each role (default true)" }
          }
        },
        timeout_ms: 5000
      ),
      tool_def(
        tool_key: "get_work_experience",
        name: "Get work experience details",
        description: "Get detailed information about a specific work experience.",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::GetWorkExperienceTool",
        arg_schema: {
          type: "object",
          properties: {
            experience_id: { type: "number", description: "ID of the work experience to retrieve" }
          },
          required: [ "experience_id" ]
        },
        timeout_ms: 5000
      ),

      # Profile Update Tool
      tool_def(
        tool_key: "update_profile",
        name: "Update profile",
        description: "Update the user's profile attributes: years of experience, current company/role, social URLs, bio.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::UpdateProfileTool",
        arg_schema: {
          type: "object",
          properties: {
            years_of_experience: { type: "number", description: "Total years of professional experience (0-60)" },
            current_company_name: { type: "string", description: "Current employer name" },
            current_job_role_title: { type: "string", description: "Current job title" },
            linkedin_url: { type: "string", description: "LinkedIn profile URL" },
            github_url: { type: "string", description: "GitHub profile URL" },
            twitter_url: { type: "string", description: "Twitter/X profile URL" },
            portfolio_url: { type: "string", description: "Portfolio or personal website URL" },
            gitlab_url: { type: "string", description: "GitLab profile URL" },
            bio: { type: "string", description: "Short bio or professional summary" }
          }
        },
        timeout_ms: 8000
      ),

      # Interview Prep Tools
      tool_def(
        tool_key: "get_interview_prep",
        name: "Get interview prep",
        description: "Get interview preparation artifacts for a specific application (match analysis, focus areas, strength positioning, question framing).",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::GetInterviewPrepTool",
        arg_schema: {
          type: "object",
          properties: {
            application_id: { type: "number", description: "ID of the interview application" }
          },
          required: [ "application_id" ]
        },
        timeout_ms: 5000
      ),
      tool_def(
        tool_key: "generate_interview_prep",
        name: "Generate interview prep",
        description: "Generate interview preparation artifacts for a specific application. Creates match analysis, focus areas, strength positioning, and question framing.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::GenerateInterviewPrepTool",
        arg_schema: {
          type: "object",
          properties: {
            application_id: { type: "number", description: "ID of the interview application" },
            kinds: {
              oneOf: [
                { type: "string", enum: [ "all" ], description: "Generate all prep types" },
                {
                  type: "array",
                  items: {
                    type: "string",
                    enum: [ "match_analysis", "focus_areas", "strength_positioning", "question_framing" ]
                  },
                  description: "Specific prep types to generate"
                }
              ],
              description: "Which prep artifacts to generate (default: all)"
            }
          },
          required: [ "application_id" ]
        },
        timeout_ms: 60000
      ),

      # Skills Tools
      tool_def(
        tool_key: "list_skills",
        name: "List skills",
        description: "List the user's skills with proficiency levels, categories, and evidence.",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::ListSkillsTool",
        arg_schema: {
          type: "object",
          properties: {
            limit: { type: "number", description: "Maximum number of skills to return (1-100, default 25)" },
            category: { type: "string", description: "Filter by category (e.g., Backend, Frontend, Leadership)" },
            filter: {
              type: "string",
              enum: [ "all", "strong", "moderate", "developing" ],
              description: "Filter by proficiency level (default: all)"
            }
          }
        },
        timeout_ms: 5000
      ),
      tool_def(
        tool_key: "get_skill_details",
        name: "Get skill details",
        description: "Get detailed information about a specific skill including evidence and work experiences where it was used.",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::GetSkillDetailsTool",
        arg_schema: {
          type: "object",
          properties: {
            skill_id: { type: "number", description: "ID of the user skill" },
            skill_name: { type: "string", description: "Name of the skill to look up" }
          }
        },
        timeout_ms: 5000
      )
    ].map { |t| t.merge(created_at: now, updated_at: now) }

    AssistantTool.upsert_all(tools, unique_by: :index_assistant_tools_on_tool_key)
  end

  def down
    execute <<~SQL.squish
      DELETE FROM assistant_tools
      WHERE tool_key IN (
        'list_target_domains',
        'add_target_domain',
        'remove_target_domain',
        'list_work_history',
        'get_work_experience',
        'update_profile',
        'get_interview_prep',
        'generate_interview_prep',
        'list_skills',
        'get_skill_details'
      )
    SQL
  end

  private

  def tool_def(tool_key:, name:, description:, risk_level:, requires_confirmation:, executor_class:, arg_schema:, timeout_ms:)
    {
      tool_key: tool_key,
      name: name,
      description: description,
      enabled: true,
      risk_level: risk_level,
      requires_confirmation: requires_confirmation,
      executor_class: executor_class,
      arg_schema: arg_schema,
      timeout_ms: timeout_ms,
      rate_limit: {}
    }
  end
end
