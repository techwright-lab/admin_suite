# frozen_string_literal: true

module Ai
  # Prompt template for summarizing an assistant thread.
  #
  # Variables:
  # - {{existing_summary}}
  # - {{messages}}
  class AssistantThreadSummaryPrompt < LlmPrompt
    def self.default_prompt_template
      <<~PROMPT
        You are summarizing an assistant chat thread. Produce a concise summary that preserves:
        - user goals and constraints
        - decisions and commitments
        - key context needed to continue the conversation

        Existing summary (may be empty):
        {{existing_summary}}

        New messages (role and content):
        {{messages}}

        Output only the updated summary text.
      PROMPT
    end

    def self.default_system_prompt
      <<~PROMPT
        You are summarizing an assistant chat thread. Your goal is to produce a concise summary that preserves:
        - user goals and constraints
        - decisions and commitments
        - key context needed to continue the conversation
        You should only return the updated summary text.
        Do not include markdown or extra commentary.
        Do not include any other text or formatting.
        Do not include any other text or formatting.
      PROMPT
    end

    def self.default_variables
      {
        "existing_summary" => { "required" => false, "description" => "Current summary text" },
        "messages" => { "required" => true, "description" => "Recent messages to incorporate" }
      }
    end
  end
end
