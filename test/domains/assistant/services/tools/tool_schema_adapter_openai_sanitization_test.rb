# frozen_string_literal: true

require "test_helper"

module Assistant
  module Tools
    class ToolSchemaAdapterOpenaiSanitizationTest < ActiveSupport::TestCase
      test "openai tool schema strips top-level anyOf/oneOf/allOf/enum/not" do
        tool = Assistant::Tool.create!(
          tool_key: "add_note_to_application",
          name: "Add note to application",
          description: "Append or replace notes on an interview application.",
          enabled: true,
          risk_level: "write_low",
          requires_confirmation: true,
          executor_class: "Assistant::Tools::AddNoteToApplicationTool",
          timeout_ms: 5000,
          rate_limit: {},
          arg_schema: {
            type: "object",
            properties: {
              application_uuid: { type: "string" },
              application_id: { type: "number" },
              note: { type: "string" }
            },
            required: [ "note" ],
            anyOf: [
              { required: [ "application_uuid" ] },
              { required: [ "application_id" ] }
            ]
          }
        )
        schema = Assistant::Tools::ToolSchemaAdapter.new([ tool ]).for_openai.first.fetch(:parameters)

        assert_equal "object", schema["type"] || schema[:type]
        refute schema.key?("anyOf")
        refute schema.key?(:anyOf)
        refute schema.key?("oneOf")
        refute schema.key?(:oneOf)
        refute schema.key?("allOf")
        refute schema.key?(:allOf)
        refute schema.key?("enum")
        refute schema.key?(:enum)
        refute schema.key?("not")
        refute schema.key?(:not)
      end
    end
  end
end
