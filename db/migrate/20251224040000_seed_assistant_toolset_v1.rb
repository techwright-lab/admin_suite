# frozen_string_literal: true

class SeedAssistantToolsetV1 < ActiveRecord::Migration[8.1]
  class AssistantTool < ActiveRecord::Base
    self.table_name = "assistant_tools"
  end

  def up
    now = Time.current

    tools = [
      tool_def(
        tool_key: "get_profile_summary",
        name: "Get profile summary",
        description: "Return a compact summary of the user profile, pipeline, and top skills.",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::GetProfileSummaryTool",
        arg_schema: {
          type: "object",
          properties: {
            top_skills_limit: { type: "number" }
          }
        },
        timeout_ms: 5000
      ),
      tool_def(
        tool_key: "list_interview_applications",
        name: "List interview applications",
        description: "List the user's interview applications, optionally filtered by status and pipeline stage.",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::ListInterviewApplicationsTool",
        arg_schema: {
          type: "object",
          properties: {
            status: { type: "string" },
            pipeline_stage: { type: "string" },
            limit: { type: "number" }
          }
        },
        timeout_ms: 8000
      ),
      tool_def(
        tool_key: "get_interview_application",
        name: "Get interview application",
        description: "Get details for one interview application, including interview rounds.",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::GetInterviewApplicationTool",
        arg_schema: {
          type: "object",
          required: [ "application_uuid" ],
          properties: {
            application_uuid: { type: "string" }
          }
        },
        timeout_ms: 8000
      ),
      tool_def(
        tool_key: "get_next_interview",
        name: "Get next interview",
        description: "Return the next upcoming interview round for the user (across all applications).",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::GetNextInterviewTool",
        arg_schema: { type: "object", properties: {} },
        timeout_ms: 5000
      ),
      tool_def(
        tool_key: "create_interview_round",
        name: "Create interview round",
        description: "Create/schedule an interview round for an application (can be future or retroactive).",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::CreateInterviewRoundTool",
        arg_schema: {
          type: "object",
          required: [ "application_uuid", "stage" ],
          properties: {
            application_uuid: { type: "string" },
            stage: { type: "string" },
            stage_name: { type: "string" },
            result: { type: "string" },
            scheduled_at: { type: "string" },
            completed_at: { type: "string" },
            duration_minutes: { type: "number" },
            interviewer_name: { type: "string" },
            interviewer_role: { type: "string" },
            notes: { type: "string" },
            position: { type: "number" }
          }
        },
        timeout_ms: 10_000
      ),
      tool_def(
        tool_key: "get_interview_feedback",
        name: "Get interview feedback",
        description: "Fetch manual/AI feedback for an interview round (if present).",
        risk_level: "read_only",
        requires_confirmation: false,
        executor_class: "Assistant::Tools::GetInterviewFeedbackTool",
        arg_schema: {
          type: "object",
          required: [ "interview_round_id" ],
          properties: {
            interview_round_id: { type: "number" }
          }
        },
        timeout_ms: 5000
      ),
      tool_def(
        tool_key: "upsert_interview_feedback",
        name: "Upsert interview feedback",
        description: "Create or update manual interview feedback for a round.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::UpsertInterviewFeedbackTool",
        arg_schema: {
          type: "object",
          required: [ "interview_round_id" ],
          properties: {
            interview_round_id: { type: "number" },
            went_well: { type: "string" },
            to_improve: { type: "string" },
            self_reflection: { type: "string" },
            interviewer_notes: { type: "string" },
            recommended_action: { type: "string" },
            tags: { type: "array" }
          }
        },
        timeout_ms: 10_000
      ),
      tool_def(
        tool_key: "add_note_to_application",
        name: "Add note to application",
        description: "Append or replace notes on an interview application.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::AddNoteToApplicationTool",
        arg_schema: {
          type: "object",
          required: [ "application_uuid", "note" ],
          properties: {
            application_uuid: { type: "string" },
            note: { type: "string" },
            mode: { type: "string" }
          }
        },
        timeout_ms: 5000
      ),
      tool_def(
        tool_key: "add_target_company",
        name: "Add target company",
        description: "Add a company to the user's target companies list.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::AddTargetCompanyTool",
        arg_schema: {
          type: "object",
          properties: {
            company_id: { type: "number" },
            company_name: { type: "string" },
            priority: { type: "number" }
          }
        },
        timeout_ms: 8000
      ),
      tool_def(
        tool_key: "add_target_job_role",
        name: "Add target job role",
        description: "Add a job role to the user's target job roles list.",
        risk_level: "write_low",
        requires_confirmation: true,
        executor_class: "Assistant::Tools::AddTargetJobRoleTool",
        arg_schema: {
          type: "object",
          properties: {
            job_role_id: { type: "number" },
            job_role_title: { type: "string" },
            priority: { type: "number" }
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
        'get_profile_summary',
        'list_interview_applications',
        'get_interview_application',
        'get_next_interview',
        'create_interview_round',
        'get_interview_feedback',
        'upsert_interview_feedback',
        'add_note_to_application',
        'add_target_company',
        'add_target_job_role'
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
