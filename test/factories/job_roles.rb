FactoryBot.define do
  factory :job_role do
    sequence(:title) { |n| "Software Engineer #{n}" }
    category { Category.find_or_create_by!(name: "Engineering", kind: :job_role) }
    legacy_category { "Engineering" }
    description { "A software engineering role" }

    trait :engineering do
      title { "Senior Software Engineer" }
      category { Category.find_or_create_by!(name: "Engineering", kind: :job_role) }
      legacy_category { "Engineering" }
    end

    trait :product do
      title { "Product Manager" }
      category { Category.find_or_create_by!(name: "Product", kind: :job_role) }
      legacy_category { "Product" }
    end
  end
end
