FactoryBot.define do
  factory :scraping_attempt do
    association :job_listing
    
    url { "https://example.com/jobs/123" }
    domain { "example.com" }
    status { :pending }
    retry_count { 0 }

    trait :completed do
      status { :completed }
      extraction_method { "ai" }
      provider { "anthropic" }
      confidence_score { 0.9 }
      duration_seconds { 15.5 }
    end

    trait :failed do
      status { :failed }
      error_message { "Extraction failed" }
      retry_count { 1 }
    end

    trait :dead_letter do
      status { :dead_letter }
      error_message { "Failed after 3 attempts" }
      retry_count { 3 }
    end

    trait :with_api_extraction do
      extraction_method { "api" }
      provider { "greenhouse" }
      confidence_score { 1.0 }
      http_status { 200 }
    end
  end
end

