# frozen_string_literal: true

FactoryBot.define do
  factory :opportunity do
    user
    status { "new" }
    source_type { "direct_email" }
    company_name { "Test Company" }
    job_role_title { "Software Engineer" }
    recruiter_name { "John Recruiter" }
    recruiter_email { "john@recruiting.com" }
    ai_confidence_score { 0.85 }

    trait :with_synced_email do
      synced_email
    end

    trait :with_job_url do
      job_url { "https://example.com/jobs/123" }
    end

    trait :linkedin_forward do
      source_type { "linkedin_forward" }
      extracted_data { { is_forwarded: true, original_source: "linkedin" } }
    end

    trait :referral do
      source_type { "referral" }
    end

    trait :reviewing do
      status { "reviewing" }
    end

    trait :applied do
      status { "applied" }
      association :interview_application
    end

    trait :ignored do
      status { "ignored" }
    end

    trait :with_extracted_links do
      extracted_links do
        [
          { url: "https://example.com/jobs/123", type: "job_posting", description: "Job listing" },
          { url: "https://example.com/about", type: "company_website", description: "Company page" }
        ]
      end
    end

    trait :with_key_details do
      key_details { "Remote position, $150k-$180k, Series B startup, React/Node.js stack" }
    end
  end
end
