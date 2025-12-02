FactoryBot.define do
  factory :extraction_prompt_template do
    name { "MyString" }
    description { "MyText" }
    prompt_template { "MyText" }
    active { false }
    version { 1 }
  end
end
