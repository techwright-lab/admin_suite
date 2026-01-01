# frozen_string_literal: true

class AddListTargetTools < ActiveRecord::Migration[8.1]
  class AssistantTool < ActiveRecord::Base
    self.table_name = "assistant_tools"
  end

  def up
    now = Time.current

    tools = [
      tool_def(
        tool_key: "list_target_companies",
        name: "List target companies",
        description: "List the user's target companies. Returns company names and priorities.",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::ListTargetCompaniesTool",
        arg_schema: {
          type: "object",
          properties: {
            limit: { type: "number" }
          }
        },
        timeout_ms: 5000
      ),
      tool_def(
        tool_key: "list_target_job_roles",
        name: "List target job roles",
        description: "List the user's target job roles. Returns job role titles and priorities.",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::ListTargetJobRolesTool",
        arg_schema: {
          type: "object",
          properties: {
            limit: { type: "number" }
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
        'list_target_companies',
        'list_target_job_roles'
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
