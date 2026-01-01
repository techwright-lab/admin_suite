# frozen_string_literal: true

class UpdateAddTargetCompanyForBatch < ActiveRecord::Migration[8.1]
  class AssistantTool < ActiveRecord::Base
    self.table_name = "assistant_tools"
  end

  def up
    tool = AssistantTool.find_by(tool_key: "add_target_company")
    return unless tool

    tool.update!(
      description: "Add one or more companies to the user's target companies list.",
      arg_schema: {
        type: "object",
        properties: {
          # Single add (backward compatible)
          company_id: { type: "number" },
          company_name: { type: "string" },
          priority: { type: "number" },

          # Batch add
          companies: {
            type: "array",
            items: {
              type: "object",
              properties: {
                company_id: { type: "number" },
                company_name: { type: "string" },
                priority: { type: "number" }
              }
            }
          }
        }
      }
    )
  end

  def down
    tool = AssistantTool.find_by(tool_key: "add_target_company")
    return unless tool

    tool.update!(
      description: "Add a company to the user's target companies list.",
      arg_schema: {
        type: "object",
        properties: {
          company_id: { type: "number" },
          company_name: { type: "string" },
          priority: { type: "number" }
        }
      }
    )
  end
end
