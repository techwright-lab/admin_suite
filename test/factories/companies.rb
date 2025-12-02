FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Company #{n}" }
    website { "https://example.com" }
    about { "A great company to work for" }
    logo_url { "https://example.com/logo.png" }

    trait :with_logo do
      logo_url { "https://logo.clearbit.com/example.com" }
    end

    trait :tech_company do
      name { "Google" }
      website { "https://google.com" }
    end
  end
end
