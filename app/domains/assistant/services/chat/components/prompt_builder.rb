# frozen_string_literal: true

module Assistant
  module Chat
    module Components
      class PromptBuilder
        MAX_HISTORY_MESSAGES = 20

        def initialize(context:, question:, allowed_tools:, conversation_history: [])
          @context = context
          @question = question.to_s
          @allowed_tools = allowed_tools
          @conversation_history = Array(conversation_history)
        end

        def build
          tool_list = allowed_tools.map do |t|
            {
              tool_key: t.tool_key,
              description: t.description,
              arg_schema: t.arg_schema,
              requires_confirmation: t.requires_confirmation,
              risk_level: t.risk_level
            }
          end

          sections = []

          sections << <<~SECTION
            CONTEXT (JSON):
            #{context.to_json}
          SECTION

          sections << <<~SECTION
            AVAILABLE_TOOLS (JSON):
            #{tool_list.to_json}
          SECTION

          if conversation_history.any?
            sections << <<~SECTION
              CONVERSATION_HISTORY:
              #{format_conversation_history}
            SECTION
          end

          sections << <<~SECTION
            USER_QUESTION:
            #{question}
          SECTION

          sections.join("\n")
        end

        private

        attr_reader :context, :question, :allowed_tools, :conversation_history

        def format_conversation_history
          # Take the most recent messages, respecting the limit
          recent_messages = conversation_history.last(MAX_HISTORY_MESSAGES)

          recent_messages.map do |msg|
            role = msg[:role] || msg["role"]
            content = msg[:content] || msg["content"]
            "[#{role.upcase}]: #{content}"
          end.join("\n\n")
        end
      end
    end
  end
end
