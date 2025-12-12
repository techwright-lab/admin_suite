# Seed LLM Provider Configurations
#
# This creates default LLM provider configurations that can be modified via the admin interface.

puts "Seeding LLM Provider Configurations..."

# Anthropic Claude Sonnet 4.5 (Primary - Priority 0)
# Latest model with best balance of intelligence, speed, and cost
# Reference: https://platform.claude.com/docs/en/about-claude/models/overview
LlmProviderConfig.find_or_create_by!(provider_type: "anthropic", name: "Claude Sonnet 4.5") do |config|
  config.llm_model = "claude-sonnet-4-5-20250929"
  config.max_tokens = 64000  # Supports up to 64K output tokens
  config.temperature = 0.0
  config.enabled = true
  config.priority = 0
  config.settings = {
    "context_window" => 200000,
    "supports_extended_thinking" => true,
    "knowledge_cutoff" => "Jan 2025"
  }
end

# Anthropic Claude Haiku 4.5 (Fast Alternative - Priority 1)
# Fastest model with near-frontier intelligence
LlmProviderConfig.find_or_create_by!(provider_type: "anthropic", name: "Claude Haiku 4.5") do |config|
  config.llm_model = "claude-haiku-4-5-20251001"
  config.max_tokens = 64000
  config.temperature = 0.0
  config.enabled = true
  config.priority = 1
  config.settings = {
    "context_window" => 200000,
    "supports_extended_thinking" => true,
    "knowledge_cutoff" => "Feb 2025"
  }
end

# OpenAI GPT-5.1 (Primary OpenAI - Priority 2)
# Latest GPT-5 flagship model
# Reference: https://platform.openai.com/docs/models/gpt-5.1
LlmProviderConfig.find_or_create_by!(provider_type: "openai", name: "GPT-5.1") do |config|
  config.llm_model = "gpt-5.1"
  config.max_tokens = 16384
  config.temperature = 0.0
  config.enabled = true
  config.priority = 2
  config.settings = {
    "supports_structured_outputs" => true,
    "supports_json_mode" => true,
    "supports_vision" => true
  }
end

# OpenAI GPT-5 Mini (Cost-Effective - Priority 3)
# Smaller, faster, more affordable GPT-5 variant
# Reference: https://platform.openai.com/docs/models/gpt-5-mini
LlmProviderConfig.find_or_create_by!(provider_type: "openai", name: "GPT-5 Mini") do |config|
  config.llm_model = "gpt-5-mini"
  config.max_tokens = 16384
  config.temperature = 0.0
  config.enabled = true
  config.priority = 3
  config.settings = {
    "supports_structured_outputs" => true,
    "supports_json_mode" => true,
    "supports_vision" => true
  }
end

# OpenAI o3 (Advanced Reasoning - Priority 4)
# Latest reasoning model with enhanced capabilities
LlmProviderConfig.find_or_create_by!(provider_type: "openai", name: "OpenAI o3") do |config|
  config.llm_model = "o3"
  config.max_tokens = 100000
  config.temperature = 1.0
  config.enabled = false  # Disabled by default due to cost
  config.priority = 4
  config.settings = {
    "reasoning_model" => true,
    "extended_reasoning" => true
  }
end

# OpenAI o3-mini (Cost-Effective Reasoning - Priority 5)
# Smaller reasoning model, more affordable
LlmProviderConfig.find_or_create_by!(provider_type: "openai", name: "OpenAI o3-mini") do |config|
  config.llm_model = "o3-mini"
  config.max_tokens = 100000
  config.temperature = 1.0
  config.enabled = false  # Disabled by default
  config.priority = 5
  config.settings = {
    "reasoning_model" => true
  }
end

# Anthropic Claude Opus 4.1 (High-End - Priority 5, Disabled by default)
# Exceptional for specialized reasoning tasks
LlmProviderConfig.find_or_create_by!(provider_type: "anthropic", name: "Claude Opus 4.1") do |config|
  config.llm_model = "claude-opus-4-1-20250805"
  config.max_tokens = 32000
  config.temperature = 0.0
  config.enabled = false  # Disabled by default due to cost
  config.priority = 5
  config.settings = {
    "context_window" => 200000,
    "supports_extended_thinking" => true,
    "knowledge_cutoff" => "Jan 2025"
  }
end

# Ollama Llama (Local - Priority 6, Disabled by default)
LlmProviderConfig.find_or_create_by!(provider_type: "ollama", name: "Llama 3.3 (Local)") do |config|
  config.llm_model = "llama3.3"
  config.api_endpoint = "http://localhost:11434"
  config.max_tokens = 8192
  config.temperature = 0.0
  config.enabled = false
  config.priority = 6
  config.settings = {}
end

# Ollama Qwen (Local - Priority 7, Disabled by default)
LlmProviderConfig.find_or_create_by!(provider_type: "ollama", name: "Qwen 2.5 (Local)") do |config|
  config.llm_model = "qwen2.5:latest"
  config.api_endpoint = "http://localhost:11434"
  config.max_tokens = 8192
  config.temperature = 0.0
  config.enabled = false
  config.priority = 7
  config.settings = {}
end

puts "✓ Created #{LlmProviderConfig.count} LLM provider configurations"

# Note: LLM prompt templates are now seeded via db/seeds/llm_prompts.rb
# using the new Ai::LlmPrompt STI model hierarchy
