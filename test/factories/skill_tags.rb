# frozen_string_literal: true

FactoryBot.define do
  factory :skill_tag do
    sequence(:name) { |n| "Skill #{n}" }
    category { "Technical" }

    trait :system_design do
      name { "System Design" }
      category { "Technical" }
    end

    trait :communication do
      name { "Communication" }
      category { "Soft Skills" }
    end

    trait :leadership do
      name { "Leadership" }
      category { "Soft Skills" }
    end

    trait :programming_language do
      sequence(:name) { |n| ["Ruby", "Python", "JavaScript", "Go", "Java"][n % 5] }
      category { "Programming Languages" }
    end
  end
end

