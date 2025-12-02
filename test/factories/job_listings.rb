FactoryBot.define do
  factory :job_listing do
    association :company
    association :job_role
    
    title { "Senior Software Engineer" }
    url { "https://example.com/jobs/123" }
    source_id { "job-123" }
    job_board_id { "linkedin-456" }
    description { "Join our team to build amazing products" }
    requirements { "5+ years of experience, Ruby on Rails, PostgreSQL" }
    responsibilities { "Design and implement features, mentor junior developers" }
    salary_min { 120000 }
    salary_max { 180000 }
    salary_currency { "USD" }
    equity_info { "0.1% - 0.5% equity" }
    benefits { "Health insurance, 401k matching, unlimited PTO" }
    perks { "Remote work, home office stipend, learning budget" }
    location { "San Francisco, CA" }
    remote_type { :hybrid }
    status { :active }
    custom_sections { {} }
    scraped_data { {} }

    trait :remote do
      remote_type { :remote }
      location { "Remote" }
    end

    trait :on_site do
      remote_type { :on_site }
    end

    trait :with_custom_sections do
      custom_sections do
        {
          "what_youll_do" => "Build scalable systems",
          "what_we_offer" => "Competitive compensation and great culture"
        }
      end
    end

    trait :with_scraped_data do
      scraped_data do
        {
          "scraped_at" => Time.current.iso8601,
          "source" => "linkedin",
          "raw_html" => "<div>Job posting</div>"
        }
      end
    end

    trait :closed do
      status { :closed }
    end
  end
end
