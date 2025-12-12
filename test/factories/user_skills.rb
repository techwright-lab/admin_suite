# frozen_string_literal: true

FactoryBot.define do
  factory :user_skill do
    user
    skill_tag
    aggregated_level { rand(1.0..5.0).round(2) }
    confidence_score { rand(0.5..1.0).round(2) }
    category { ResumeSkill::CATEGORIES.sample }
    resume_count { rand(1..5) }
    max_years_experience { rand(1..10) }
    last_demonstrated_at { rand(1..365).days.ago }

    trait :strong do
      aggregated_level { rand(4.0..5.0).round(2) }
    end

    trait :moderate do
      aggregated_level { rand(2.5..3.9).round(2) }
    end

    trait :developing do
      aggregated_level { rand(1.0..2.4).round(2) }
    end

    trait :backend do
      category { "Backend" }
    end

    trait :frontend do
      category { "Frontend" }
    end

    trait :leadership do
      category { "Leadership" }
    end
  end
end
