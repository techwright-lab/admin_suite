# frozen_string_literal: true

class AllowApplicationIdForNoteAndGetApplicationTools < ActiveRecord::Migration[8.1]
  class AssistantTool < ActiveRecord::Base
    self.table_name = "assistant_tools"
  end

  def up
    now = Time.current

    # Allow either application_uuid (preferred) or application_id (fallback) for add_note_to_application
    AssistantTool.where(tool_key: "add_note_to_application").update_all(
      arg_schema: {
        type: "object",
        properties: {
          application_uuid: { type: "string" },
          application_id: { type: "number" },
          note: { type: "string" },
          mode: { type: "string" }
        },
        required: [ "note" ],
        anyOf: [
          { required: [ "application_uuid" ] },
          { required: [ "application_id" ] }
        ]
      },
      updated_at: now
    )

    # Allow either application_uuid or application_id for get_interview_application (read tool).
    AssistantTool.where(tool_key: "get_interview_application").update_all(
      arg_schema: {
        type: "object",
        properties: {
          application_uuid: { type: "string" },
          application_id: { type: "number" }
        },
        anyOf: [
          { required: [ "application_uuid" ] },
          { required: [ "application_id" ] }
        ]
      },
      updated_at: now
    )
  end

  def down
    now = Time.current

    AssistantTool.where(tool_key: "add_note_to_application").update_all(
      arg_schema: {
        type: "object",
        required: [ "application_uuid", "note" ],
        properties: {
          application_uuid: { type: "string" },
          note: { type: "string" },
          mode: { type: "string" }
        }
      },
      updated_at: now
    )

    AssistantTool.where(tool_key: "get_interview_application").update_all(
      arg_schema: {
        type: "object",
        required: [ "application_uuid" ],
        properties: {
          application_uuid: { type: "string" }
        }
      },
      updated_at: now
    )
  end
end

