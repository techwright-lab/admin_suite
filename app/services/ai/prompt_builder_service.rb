# frozen_string_literal: true

module Ai
  # Service for building LLM prompts from prompt templates and variables.
  #
  # Uses the active prompt record when available; otherwise falls back to the
  # class-level default prompt template and performs simple variable substitution.
  #
  # @example
  #   prompt = Ai::PromptBuilderService.new(
  #     prompt_class: Ai::EmailExtractionPrompt,
  #     variables: { subject: "Hello", body: "..." }
  #   ).run
  class PromptBuilderService
    # @param prompt_class [Class] Prompt class (e.g., Ai::EmailExtractionPrompt)
    # @param variables [Hash] Variables used for prompt substitution
    def initialize(prompt_class:, variables:)
      @prompt_class = prompt_class
      @variables = variables || {}
      validate!
    end

    # Builds the prompt string.
    #
    # @return [String]
    def run
      template_record = prompt_class.active_prompt
      return template_record.build_prompt(variables) if template_record

      build_from_default_template
    end

    private

    attr_reader :prompt_class, :variables

    def validate!
      return if prompt_class.respond_to?(:active_prompt) && prompt_class.respond_to?(:default_prompt_template)

      raise ArgumentError, "prompt_class must respond to active_prompt and default_prompt_template"
    end

    def build_from_default_template
      prompt = prompt_class.default_prompt_template.dup
      variables.each do |key, value|
        prompt.gsub!("{{#{key}}}", value.to_s)
      end
      prompt
    end
  end
end
