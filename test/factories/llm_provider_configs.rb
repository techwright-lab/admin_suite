FactoryBot.define do
  factory :llm_provider_config do
    name { "MyString" }
    provider_type { "MyString" }
    llm_model { "MyString" }
    api_endpoint { "MyString" }
    max_tokens { 1 }
    temperature { 1.5 }
    enabled { false }
    priority { 1 }
    settings { "" }
  end
end
