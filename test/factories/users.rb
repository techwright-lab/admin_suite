# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password" }
    password_confirmation { "password" }
    terms_accepted { true }
    name { "John Doe" }
    bio { "Experienced software engineer" }
    years_of_experience { 5 }
    linkedin_url { "https://linkedin.com/in/johndoe" }
    github_url { "https://github.com/johndoe" }
    email_verified_at { Time.current } # Default: verified

    # Optional associations
    current_job_role { nil }
    current_company { nil }

    after(:create) do |user|
      # User preference is automatically created by after_create callback
      # We can update it if needed
      user.preference.update(
        preferred_view: "kanban",
        theme: "system"
      )
    end

    trait :with_current_role do
      association :current_job_role, factory: :job_role
    end

    trait :with_current_company do
      association :current_company, factory: :company
    end

    trait :with_targets do
      after(:create) do |user|
        user.target_job_roles << create_list(:job_role, 2)
        user.target_companies << create_list(:company, 2)
      end
    end

    trait :with_applications do
      after(:create) do |user|
        create_list(:interview_application, 3, user: user)
      end
    end

    trait :with_complete_profile do
      bio { "Senior software engineer with 10 years of experience in web development" }
      years_of_experience { 10 }
      twitter_url { "https://twitter.com/johndoe" }
      portfolio_url { "https://johndoe.com" }
      gitlab_url { "https://gitlab.com/johndoe" }
      
      association :current_job_role, factory: :job_role
      association :current_company, factory: :company
      
      after(:create) do |user|
        user.target_job_roles << create_list(:job_role, 2)
        user.target_companies << create_list(:company, 2)
      end
    end

    trait :unverified do
      email_verified_at { nil }
    end

    trait :oauth_user do
      oauth_provider { "google_oauth2" }
      sequence(:oauth_uid) { |n| "google_#{n}" }
      email_verified_at { Time.current }
      password { SecureRandom.hex(32) }
      password_confirmation { password }
    end
  end
end

