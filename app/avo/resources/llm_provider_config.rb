class Avo::Resources::LlmProviderConfig < Avo::BaseResource
  self.title = :display_name
  self.includes = []

  def fields
    field :id, as: :id
    
    # Configuration Status
    field :enabled, as: :boolean
    field :ready, as: :boolean, computed: true, readonly: true do
      record.ready? ? "✓ Ready" : "✗ Not Ready"
    end
    
    # Basic Info
    field :name, as: :text, required: true, help: "Display name for this provider"
    field :provider_type, as: :select, enum: LlmProviderConfig::PROVIDER_TYPES.map(&:to_s), required: true
    field :llm_model, as: :text, required: true, help: "Model identifier (e.g., gpt-4o, claude-3-5-sonnet-20241022)"
    field :priority, as: :number, required: true, help: "Lower number = higher priority (0 is highest)"
    
    # Model Parameters
    field :max_tokens, as: :number, default: 4096, help: "Maximum tokens for response"
    field :temperature, as: :number, default: 0.0, help: "Temperature (0.0 = deterministic, 2.0 = creative)"
    field :api_endpoint, as: :text, help: "Custom API endpoint (for Ollama or custom deployments)"
    
    # Additional Settings
    field :settings, as: :code, language: "json", help: "Additional provider-specific settings as JSON"
    
    # API Key Status
    field :api_key_status, as: :badge, computed: true, readonly: true, only_on: [:show, :index] do
      if record.api_key_configured?
        { label: "Configured", color: :success }
      else
        { label: "Missing", color: :danger }
      end
    end
    
    # Timestamps
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true
  end

  def filters
    filter EnabledFilter
    filter ProviderTypeFilter
  end

  def actions
    action Avo::Actions::TestLlmProvider
  end
  
  # Enabled filter
  class EnabledFilter < Avo::Filters::BooleanFilter
    self.name = "Enabled"
    
    def apply(request, query, value)
      return query unless value
      
      query.where(enabled: true)
    end
  end
  
  # Provider type filter
  class ProviderTypeFilter < Avo::Filters::SelectFilter
    self.name = "Provider Type"
    
    def apply(request, query, value)
      query.where(provider_type: value)
    end
    
    def options
      LlmProviderConfig::PROVIDER_TYPES.map { |t| [t.to_s.titleize, t] }
    end
  end
end
