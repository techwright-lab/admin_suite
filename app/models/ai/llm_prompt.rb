# frozen_string_literal: true

module Ai
  # Base class for LLM prompts using STI (Single Table Inheritance)
  #
  # Provides common functionality for all prompt types with support for:
  # - Version management
  # - Active/inactive status with only one active per type
  # - Variable substitution in templates
  #
  # @example
  #   prompt = Ai::JobExtractionPrompt.active_prompt
  #   final_prompt = prompt.build_prompt(url: "https://...", html_content: "...")
  #
  class LlmPrompt < ApplicationRecord
    self.table_name = "llm_prompts"

    # Associations
    has_many :llm_api_logs, class_name: "Ai::LlmApiLog", dependent: :nullify

    # Validations
    validates :name, presence: true
    validates :prompt_template, presence: true
    validates :version, numericality: { only_integer: true, greater_than: 0 }
    validates :type, presence: true

    # Scopes
    scope :active_prompts, -> { where(active: true) }
    scope :inactive_prompts, -> { where(active: false) }
    scope :by_version_desc, -> { order(version: :desc) }
    scope :by_name, -> { order(:name) }

    # Callbacks
    before_save :deactivate_others_of_same_type, if: -> { active? && active_changed? }

    # Returns the currently active prompt for this type
    #
    # @return [Ai::LlmPrompt, nil] Active prompt or nil
    def self.active_prompt
      active_prompts.by_version_desc.first
    end

    # Returns the default prompt template for this type
    # Subclasses should override this method
    #
    # @return [String] Default prompt template
    def self.default_prompt_template
      raise NotImplementedError, "Subclasses must implement default_prompt_template"
    end

    # Returns the default prompt, either from DB or fallback
    #
    # @return [String] Prompt template
    def self.default_prompt
      active_prompt&.prompt_template || default_prompt_template
    end

    # Builds a prompt with variables substituted
    #
    # @param variables [Hash] Variables to substitute (e.g., url:, html_content:)
    # @return [String] Final prompt with variables replaced
    def build_prompt(variables = {})
      template = prompt_template.dup

      variables.each do |key, value|
        template.gsub!("{{#{key}}}", value.to_s)
      end

      template
    end

    # Returns placeholder variables used in template
    #
    # @return [Array<String>] Variable names found in template
    def template_variables
      prompt_template.scan(/\{\{(\w+)\}\}/).flatten.uniq
    end

    # Checks if all required variables are defined
    #
    # @return [Boolean] True if all variables are defined
    def variables_complete?
      return true if variables.blank?

      required_vars = variables.select { |_, v| v["required"] == true }.keys
      template_vars = template_variables

      required_vars.all? { |v| template_vars.include?(v) }
    end

    # Returns human-readable prompt type name
    #
    # @return [String] Type name
    def prompt_type_name
      self.class.name.demodulize.underscore.humanize.titleize
    end

    # Duplicates the prompt with incremented version
    #
    # @return [Ai::LlmPrompt] New prompt instance (not saved)
    def duplicate
      dup.tap do |new_prompt|
        new_prompt.name = "#{name} (Copy)"
        new_prompt.active = false
        new_prompt.version = version + 1
      end
    end

    private

    # Deactivates all other prompts of the same STI type
    def deactivate_others_of_same_type
      self.class.where.not(id: id).update_all(active: false)
    end
  end
end




