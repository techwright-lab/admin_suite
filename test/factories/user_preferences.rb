# frozen_string_literal: true

FactoryBot.define do
  factory :user_preference do
    association :user
    preferred_view { "kanban" }
    timezone { "UTC" }
    email_notifications { true }
    ai_summary_enabled { true }
    theme { "system" }
    ai_feedback_analysis { true }
    ai_interview_prep { true }
    ai_insights_frequency { "weekly" }
    email_weekly_digest { true }
    email_interview_reminders { true }
    data_retention_days { 0 }

    trait :list_view do
      preferred_view { "list" }
    end

    trait :dark_theme do
      theme { "dark" }
    end

    trait :light_theme do
      theme { "light" }
    end

    trait :minimal_notifications do
      email_notifications { false }
      ai_summary_enabled { false }
      email_weekly_digest { false }
      email_interview_reminders { false }
    end

    trait :ai_disabled do
      ai_summary_enabled { false }
      ai_feedback_analysis { false }
      ai_interview_prep { false }
    end
  end
end

