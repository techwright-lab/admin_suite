# frozen_string_literal: true

require "securerandom"

module Assistant
  module Chat
    module Components
      class ToolProposalRecorder
        def initialize(trace_id:, assistant_message:, tool_calls:)
          @trace_id = trace_id
          @assistant_message = assistant_message
          @tool_calls = tool_calls || []
        end

        def call
          created = []

          tool_calls.each do |tc|
            tool = Assistant::Tool.find_by(tool_key: tc[:tool_key])
            next unless tool&.enabled?

            created << Assistant::ToolExecution.create!(
              thread: assistant_message.thread,
              assistant_message: assistant_message,
              tool_key: tool.tool_key,
              args: tc[:args] || {},
              status: "proposed",
              trace_id: trace_id,
              requires_confirmation: tool.requires_confirmation || tool.risk_level != "read_only",
              idempotency_key: SecureRandom.uuid
            )
          end

          created
        end

        private

        attr_reader :trace_id, :assistant_message, :tool_calls
      end
    end
  end
end
