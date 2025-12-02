# frozen_string_literal: true

# ExtractionPromptTemplate model for dynamic prompt management
#
# Allows admins to modify and test different extraction prompts
# without code deployment. Supports versioning for A/B testing.
class ExtractionPromptTemplate < ApplicationRecord
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :prompt_template, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }

  # Scopes
  scope :active_templates, -> { where(active: true) }
  scope :by_version, -> { order(version: :desc) }

  # Callbacks
  before_save :deactivate_others, if: -> { active? && active_changed? }

  # Returns the currently active prompt template
  #
  # @return [ExtractionPromptTemplate, nil] Active template or nil
  def self.active_prompt
    active_templates.by_version.first
  end

  # Returns the default extraction prompt
  #
  # @return [String] Prompt template
  def self.default_prompt
    active_prompt&.prompt_template || fallback_prompt
  end

  # Builds a prompt with variables substituted
  #
  # @param [Hash] variables Variables to substitute (url, html_content, etc.)
  # @return [String] Final prompt
  def build_prompt(variables = {})
    template = prompt_template.dup

    variables.each do |key, value|
      template.gsub!("{{#{key}}}", value.to_s)
    end

    template
  end

  # Returns placeholder variables used in template
  #
  # @return [Array<String>] Variable names
  def template_variables
    prompt_template.scan(/\{\{(\w+)\}\}/).flatten.uniq
  end

  private

  # Deactivates all other templates when this one is activated
  def deactivate_others
    ExtractionPromptTemplate.where.not(id: id).update_all(active: false)
  end

  # Fallback prompt if no active template exists
  #
  # @return [String] Default prompt template
  def self.fallback_prompt
    <<~PROMPT
      You are an expert at extracting structured job listing data from HTML.

      Extract the following information from this job listing HTML and return it as JSON:

      Required fields:
      - title: Job title
      - company: Company name (the organization posting the job)
      - job_role: Job role/title (can be the same as title or a normalized version)
      - description: Full job description (text only, no HTML)
      - requirements: Required qualifications and skills
      - responsibilities: Key responsibilities and duties
      - location: Office location or "Remote"
      - remote_type: one of "on_site", "hybrid", or "remote"

      Optional fields (use null if not found):
      - salary_min: Minimum salary as number
      - salary_max: Maximum salary as number
      - salary_currency: Currency code (e.g., "USD", "EUR")
      - equity_info: Stock options or equity details
      - benefits: Benefits package description
      - perks: Additional perks and amenities
      - custom_sections: Any additional structured data as a JSON object

      Also provide:
      - confidence_score: Your confidence in the extraction accuracy (0.0 to 1.0)
      - notes: Any extraction challenges or uncertainties

      Job Listing URL: {{url}}

      HTML Content:
      {{html_content}}

      Return only valid JSON with no additional commentary.
    PROMPT
  end
end
