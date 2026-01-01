# frozen_string_literal: true

class UpdateAddTargetJobRoleForBatch < ActiveRecord::Migration[8.1]
  class AssistantTool < ActiveRecord::Base
    self.table_name = "assistant_tools"
  end

  def up
    tool = AssistantTool.find_by(tool_key: "add_target_job_role")
    return unless tool

    tool.update!(
      description: "Add one or more job roles to the user's target job roles list.",
      arg_schema: {
        type: "object",
        properties: {
          # Single add (backward compatible)
          job_role_id: { type: "number" },
          job_role_title: { type: "string" },
          priority: { type: "number" },

          # Batch add
          job_roles: {
            type: "array",
            items: {
              type: "object",
              properties: {
                job_role_id: { type: "number" },
                job_role_title: { type: "string" },
                priority: { type: "number" }
              }
            }
          }
        }
      }
    )
  end

  def down
    tool = AssistantTool.find_by(tool_key: "add_target_job_role")
    return unless tool

    tool.update!(
      description: "Add a job role to the user's target job roles list.",
      arg_schema: {
        type: "object",
        properties: {
          job_role_id: { type: "number" },
          job_role_title: { type: "string" },
          priority: { type: "number" }
        }
      }
    )
  end
end
