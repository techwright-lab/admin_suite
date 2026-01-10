# frozen_string_literal: true

module Ai
  # Prompt template for proposing long-term user memories (always user-confirmed).
  #
  # Variables:
  # - {{messages}}
  class AssistantMemoryProposalPrompt < LlmPrompt
    def self.default_prompt_template
      <<~PROMPT
        You are extracting durable user preferences/goals/constraints that should be remembered across chats.

        Only propose items that are explicitly stated by the user. Do not infer sensitive attributes.

        Output JSON only:
        {
          "items": [
            { "key": "string", "value": { }, "reason": "string", "confidence": 0.0 }
          ]
        }

        Keys should be stable and namespaced (examples):
        - preferences.tone
        - goals.target_role
        - constraints.timezone
        - preferences.focus_areas

        Recent messages:
        {{messages}}
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You are extracting durable user preferences/goals/constraints that should be remembered across chats.
        Only propose items that are explicitly stated by the user. Do not infer sensitive attributes.
        Return only valid JSON. Do not include markdown or extra commentary.
      PROMPT
    end

    def self.default_variables
      {
        "messages" => { "required" => true, "description" => "Recent messages to extract explicit preferences/goals from" }
      }
    end
  end
end
