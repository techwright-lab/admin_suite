# frozen_string_literal: true

FactoryBot.define do
  factory :saved_job do
    user
    status { "active" }
    title { "Saved job" }
    company_name { "Test Company" }
    job_role_title { "Software Engineer" }
    notes { "Some notes" }

    trait :from_opportunity do
      association :opportunity
      url { nil }
    end

    trait :from_url do
      opportunity { nil }
      url { "https://example.com/jobs/123" }
    end

    trait :archived do
      status { "archived" }
      archived_reason { "removed_saved_job" }
      archived_at { Time.current }
    end
  end
end



