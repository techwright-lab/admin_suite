# frozen_string_literal: true

require "timeout"

module Assistant
  module Tools
    # Executes a proposed tool execution with guardrails:
    # - tool exists/enabled
    # - schema validation
    # - confirmation required for write tools
    # - idempotency
    # - timeout
    # - structured results + audit record updates
    class Runner
      def initialize(user:, tool_execution:, approved_by: nil)
        @user = user
        @tool_execution = tool_execution
        @approved_by = approved_by
      end

      def call
        return already_done if tool_execution.status == "success"

        return fail!("unauthorized", "Not allowed") unless tool_execution.thread.user_id == user.id

        tool = Assistant::Tool.find_by(tool_key: tool_execution.tool_key)
        return fail!("tool_not_found", "Tool not found") if tool.nil?
        return fail!("tool_disabled", "Tool is disabled") unless tool.enabled?

        if tool_execution.requires_confirmation && approved_by.nil?
          return fail!("confirmation_required", "This tool requires confirmation")
        end

        errors = Assistant::Tools::ArgSchemaValidator.new(tool.arg_schema).validate(tool_execution.args)
        return fail!("schema_invalid", errors.join(", ")) if errors.any?

        tool_execution.update!(
          status: "running",
          started_at: Time.current,
          approved_by: approved_by,
          approved_at: approved_by.present? ? Time.current : nil
        )

        result = nil
        Timeout.timeout((tool.timeout_ms.to_i / 1000.0).clamp(0.1, 60.0)) do
          result = execute_tool(tool, tool_execution.args)
        end

        tool_execution.update!(
          status: (result[:success] ? "success" : "error"),
          finished_at: Time.current,
          result: result[:data] || {},
          error: result[:error]
        )

        record_event("tool_executed", severity: result[:success] ? "info" : "error", payload: {
          tool_key: tool.tool_key,
          status: tool_execution.status,
          error: tool_execution.error
        }.compact)

        result
      rescue Timeout::Error
        fail!("timeout", "Tool execution timed out")
      rescue StandardError => e
        fail!("exception", e.message)
      end

      private

      attr_reader :user, :tool_execution, :approved_by

      def already_done
        { success: true, data: tool_execution.result }
      end

      def fail!(code, message)
        tool_execution.update!(
          status: "error",
          finished_at: Time.current,
          error: message
        ) if tool_execution.persisted? && tool_execution.status != "success"

        record_event("tool_denied", severity: "warn", payload: {
          tool_key: tool_execution.tool_key,
          reason: code,
          message: message
        })

        { success: false, error: message, error_type: code }
      end

      def execute_tool(tool, args)
        klass = tool.executor_class.safe_constantize
        return { success: false, error: "Invalid executor_class", error_type: "executor_missing" } if klass.nil?

        executor = klass.new(user: user)
        unless executor.respond_to?(:call)
          return { success: false, error: "Executor does not implement #call", error_type: "executor_invalid" }
        end

        executor.call(args: args, tool_execution: tool_execution)
      end

      def record_event(event_type, severity:, payload:)
        Assistant::Ops::Event.create!(
          thread: tool_execution.thread,
          trace_id: tool_execution.trace_id,
          event_type: event_type,
          severity: severity,
          payload: payload
        )
      rescue StandardError
        # Best-effort; don't fail tool execution because events can't be recorded.
      end
    end
  end
end
