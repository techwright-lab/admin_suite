# frozen_string_literal: true

class AddRemoveTargetTools < ActiveRecord::Migration[8.1]
  class AssistantTool < ActiveRecord::Base
    self.table_name = "assistant_tools"
  end

  def up
    now = Time.current

    tools = [
      tool_def(
        tool_key: "remove_target_company",
        name: "Remove target company",
        description: "Remove one or more companies from the user's target companies list.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::RemoveTargetCompanyTool",
        arg_schema: {
          type: "object",
          properties: {
            company_id: { type: "number" },
            company_name: { type: "string" },
            companies: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  company_id: { type: "number" },
                  company_name: { type: "string" }
                }
              }
            }
          }
        },
        timeout_ms: 8000
      ),
      tool_def(
        tool_key: "remove_target_job_role",
        name: "Remove target job role",
        description: "Remove one or more job roles from the user's target job roles list.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::RemoveTargetJobRoleTool",
        arg_schema: {
          type: "object",
          properties: {
            job_role_id: { type: "number" },
            job_role_title: { type: "string" },
            job_roles: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  job_role_id: { type: "number" },
                  job_role_title: { type: "string" }
                }
              }
            }
          }
        },
        timeout_ms: 8000
      )
    ].map { |t| t.merge(created_at: now, updated_at: now) }

    AssistantTool.upsert_all(tools, unique_by: :index_assistant_tools_on_tool_key)
  end

  def down
    execute <<~SQL.squish
      DELETE FROM assistant_tools
      WHERE tool_key IN (
        'remove_target_company',
        'remove_target_job_role'
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
