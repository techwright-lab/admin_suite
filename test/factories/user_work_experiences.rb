# frozen_string_literal: true

FactoryBot.define do
  factory :user_work_experience do
    user
    sequence(:role_title) { |n| "Engineer #{n}" }
    sequence(:company_name) { |n| "Company #{n}" }
    current { false }
    start_date { rand(2..10).years.ago }
    end_date { rand(1..2).years.ago }
    highlights { [ "Built features", "Improved performance" ] }
    responsibilities { [ "Develop software", "Review code" ] }
    source_type { :ai_extracted }

    trait :current_job do
      current { true }
      end_date { nil }
    end

    trait :manual do
      source_type { :manual }
    end

    trait :with_company do
      company { association :company }
    end

    trait :with_job_role do
      job_role { association :job_role }
    end
  end
end
