# frozen_string_literal: true

require "securerandom"
require "digest"

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

            args = tc[:args] || {}
            dedupe_key = Digest::SHA256.hexdigest([ tool.tool_key, args ].to_json)
            existing = Assistant::ToolExecution.where(thread: assistant_message.thread, assistant_message: assistant_message, tool_key: tool.tool_key)
              .where("metadata ->> 'dedupe_key' = ?", dedupe_key)
              .exists?
            next if existing

            created << Assistant::ToolExecution.create!(
              thread: assistant_message.thread,
              assistant_message: assistant_message,
              tool_key: tool.tool_key,
              args: args,
              status: "proposed",
              trace_id: trace_id,
              requires_confirmation: tool.requires_confirmation || tool.risk_level != "read_only",
              idempotency_key: SecureRandom.uuid,
              provider_name: tc[:provider_name] || tc["provider_name"],
              provider_tool_call_id: tc[:provider_tool_call_id] || tc["provider_tool_call_id"],
              metadata: { dedupe_key: dedupe_key }
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
