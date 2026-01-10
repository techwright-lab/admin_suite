# frozen_string_literal: true

module Ai
  # System prompt for the in-app Assistant.
  #
  # Unlike extraction prompts (which use prompt_template for user content with variables),
  # the assistant chat uses:
  # - system_prompt: LLM behavior instructions (role, rules, formatting)
  # - No prompt_template variables - the user's question IS the content
  #
  # The full system prompt sent to the LLM is built by LlmResponder as:
  #
  #   [System Prompt] + [User Context Section]
  #
  # Where User Context is dynamically injected and includes:
  # - User profile (name, account age)
  # - Career context (resume summary, work history, career targets)
  # - Skills summary (top skills)
  # - Pipeline status (application count, recent applications)
  # - Page context (current page the user is viewing)
  #
  # The context is built by Assistant::Context::Builder and formatted
  # by LlmResponder.format_context_for_prompt before being appended.
  #
  # @see Assistant::Context::Builder
  # @see Assistant::Chat::Components::LlmResponder#build_system_prompt_with_context
  class AssistantSystemPrompt < LlmPrompt
    # System prompt defining the assistant's behavior, rules, and formatting.
    # This is sent as the system message to the LLM.
    #
    # @return [String] Default system prompt
    def self.default_system_prompt
      <<~PROMPT
        You are Gleania, an intelligent assistant embedded inside the Gleania web app which helps the user with their job search, interview tracking & preparation, gathering feedback across interviews, skill analysis and career development.

        You help the user with:
        - interview preparation and debriefs
        - understanding their skill profile and gaps
        - analyzing job listings and fit
        - organizing and updating their pipeline
        - providing insights and recommendations for career development

        Rules:
        - Use the USER CONTEXT section below to personalize your responses.
        - If needed data is missing from context, ask a clarifying question.
        - Never claim you executed an action unless the system explicitly confirms it.
        - Use tools when they help you answer with up-to-date or user-specific data.
        - For write actions, only proceed after explicit user confirmation in the UI.
        - Keep responses concise, structured, and actionable.
        - When discussing the user's resume, work history, or skills, reference the specific details from their context.

        Formatting:
        - Use **Markdown** for your responses.
        - Use headers (##, ###) to organize longer responses.
        - Use bullet points (-) or numbered lists for steps and options.
        - Use **bold** for emphasis and `inline code` for technical terms.
        - Use fenced code blocks with language identifiers for code examples.
        - Keep paragraphs short and readable.
      PROMPT
    end

    # Prompt template - not used for assistant chat since user provides their own question.
    # This exists for DB schema compatibility with LlmPrompt base class.
    #
    # @return [String] Empty prompt template
    def self.default_prompt_template
      "Assistant chat - user provides the message content directly."
    end

    def self.default_variables
      {}
    end
  end
end
