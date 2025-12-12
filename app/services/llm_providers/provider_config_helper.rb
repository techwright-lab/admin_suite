# frozen_string_literal: true

module LlmProviders
  # Configuration helper for LLM providers (database-backed)
  #
  # Provides access to provider configuration from LlmProviderConfig model.
  # Used by services to determine which providers to use and in what order.
  #
  # @example
  #   LlmProviders::ProviderConfigHelper.default_provider  # => "anthropic"
  #   LlmProviders::ProviderConfigHelper.fallback_providers  # => ["openai", "ollama"]
  #   LlmProviders::ProviderConfigHelper.all_providers  # => ["anthropic", "openai", "ollama"]
  #
  module ProviderConfigHelper
    class << self
      # Returns the default provider name
      #
      # @return [String] Default provider name
      def default_provider
        ::LlmProviderConfig.default_provider&.provider_type || "anthropic"
      end

      # Returns the list of fallback provider names
      #
      # @return [Array<String>] Fallback provider names
      def fallback_providers
        ::LlmProviderConfig.fallback_providers.pluck(:provider_type)
      end

      # Returns all available providers in priority order
      #
      # @return [Array<String>] Provider names
      def all_providers
        [ default_provider ] + fallback_providers
      end
    end
  end
end
