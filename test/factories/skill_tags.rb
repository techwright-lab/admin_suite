# frozen_string_literal: true

FactoryBot.define do
  factory :skill_tag do
    sequence(:name) { |n| "Skill #{n}" }
    category { Category.find_or_create_by!(name: "Technical", kind: :skill_tag) }
    legacy_category { "Technical" }

    trait :system_design do
      name { "System Design" }
      category { Category.find_or_create_by!(name: "Technical", kind: :skill_tag) }
      legacy_category { "Technical" }
    end

    trait :communication do
      name { "Communication" }
      category { Category.find_or_create_by!(name: "Soft Skills", kind: :skill_tag) }
      legacy_category { "Soft Skills" }
    end

    trait :leadership do
      name { "Leadership" }
      category { Category.find_or_create_by!(name: "Soft Skills", kind: :skill_tag) }
      legacy_category { "Soft Skills" }
    end

    trait :programming_language do
      sequence(:name) { |n| ["Ruby", "Python", "JavaScript", "Go", "Java"][n % 5] }
      category { Category.find_or_create_by!(name: "Programming Languages", kind: :skill_tag) }
      legacy_category { "Programming Languages" }
    end
  end
end

