FactoryBot.define do
  factory :job_role do
    sequence(:title) { |n| "Software Engineer #{n}" }
    category { "Engineering" }
    description { "A software engineering role" }

    trait :engineering do
      title { "Senior Software Engineer" }
      category { "Engineering" }
    end

    trait :product do
      title { "Product Manager" }
      category { "Product" }
    end
  end
end
