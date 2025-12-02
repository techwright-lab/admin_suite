# frozen_string_literal: true

# LlmProviderConfig model for dynamic LLM provider configuration
#
# Allows runtime configuration of LLM providers without code deployment.
# Admins can enable/disable providers, change models, adjust parameters, etc.
class LlmProviderConfig < ApplicationRecord
  PROVIDER_TYPES = [:openai, :anthropic, :ollama, :gemini].freeze

  # Validations
  validates :name, presence: true
  validates :provider_type, presence: true, inclusion: { in: PROVIDER_TYPES.map(&:to_s) }
  validates :llm_model, presence: true
  validates :max_tokens, numericality: { greater_than: 0, less_than_or_equal_to: 100000 }, allow_nil: true
  validates :temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }, allow_nil: true
  validates :priority, numericality: { only_integer: true }, allow_nil: true

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :by_priority, -> { order(priority: :asc, created_at: :asc) }
  scope :by_provider_type, ->(type) { where(provider_type: type) }

  # Returns all enabled providers in priority order
  #
  # @return [ActiveRecord::Relation] Enabled providers
  def self.active_providers
    enabled.by_priority
  end

  # Returns the default provider (highest priority enabled)
  #
  # @return [LlmProviderConfig, nil] Default provider or nil
  def self.default_provider
    active_providers.first
  end

  # Returns fallback providers (all except default)
  #
  # @return [ActiveRecord::Relation] Fallback providers
  def self.fallback_providers
    active_providers.offset(1)
  end

  # Checks if API key is configured for this provider
  #
  # @return [Boolean] True if API key exists
  def api_key_configured?
    api_key.present?
  end

  # Returns the API key from Rails credentials
  #
  # @return [String, nil] API key or nil
  def api_key
    case provider_type.to_sym
    when :openai
      Rails.application.credentials.dig(:openai, :api_key)
    when :anthropic
      Rails.application.credentials.dig(:anthropic, :api_key)
    when :gemini
      Rails.application.credentials.dig(:gemini, :api_key)
    when :ollama
      "local" # Ollama doesn't need an API key
    else
      nil
    end
  end

  # Checks if provider is ready to use
  #
  # @return [Boolean] True if enabled and has API key
  def ready?
    enabled? && api_key_configured?
  end

  # Returns display name with model info
  #
  # @return [String] Display name
  def display_name
    "#{name} (#{llm_model})"
  end

  # Returns configuration hash for provider instantiation
  #
  # @return [Hash] Configuration hash
  def to_config
    {
      provider_type: provider_type,
      model: llm_model,
      max_tokens: max_tokens,
      temperature: temperature,
      api_endpoint: api_endpoint,
      enabled: enabled,
      settings: settings
    }.compact
  end
end
