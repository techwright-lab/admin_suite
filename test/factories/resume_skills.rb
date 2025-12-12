# frozen_string_literal: true

FactoryBot.define do
  factory :resume_skill do
    user_resume
    skill_tag
    model_level { rand(1..5) }
    confidence_score { rand(0.5..1.0).round(2) }
    category { ResumeSkill::CATEGORIES.sample }
    evidence_snippet { "#{skill_tag&.name || 'This skill'} demonstrated through various projects" }
    years_of_experience { rand(0..10) }

    trait :beginner do
      model_level { 1 }
    end

    trait :intermediate do
      model_level { 3 }
    end

    trait :expert do
      model_level { 5 }
    end

    trait :user_confirmed do
      user_level { rand(1..5) }
    end

    trait :high_confidence do
      confidence_score { rand(0.8..1.0).round(2) }
    end

    trait :low_confidence do
      confidence_score { rand(0.3..0.5).round(2) }
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
