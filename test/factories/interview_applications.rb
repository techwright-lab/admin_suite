# frozen_string_literal: true

FactoryBot.define do
  factory :interview_application do
    association :user
    association :company
    association :job_role
    association :job_listing, factory: :job_listing
    
    status { :active }
    pipeline_stage { :applied }
    applied_at { 1.week.ago }
    notes { "Excited about this opportunity" }

    trait :with_rounds do
      after(:create) do |application|
        create_list(:interview_round, 2, interview_application: application)
      end
    end

    trait :with_skills do
      after(:create) do |application|
        skills = create_list(:skill_tag, 3)
        application.skill_tags << skills
      end
    end

    trait :with_company_feedback do
      after(:create) do |application|
        create(:company_feedback, interview_application: application)
      end
    end

    # Status traits
    trait :active do
      status { :active }
    end

    trait :archived do
      status { :archived }
    end

    trait :rejected do
      status { :rejected }
    end

    trait :accepted do
      status { :accepted }
    end

    # Pipeline stage traits
    trait :applied_stage do
      pipeline_stage { :applied }
      applied_at { 1.week.ago }
    end

    trait :screening_stage do
      pipeline_stage { :screening }
      applied_at { 2.weeks.ago }
      
      after(:create) do |application|
        create(:interview_round, :screening, interview_application: application)
      end
    end

    trait :interviewing_stage do
      pipeline_stage { :interviewing }
      applied_at { 3.weeks.ago }
      
      after(:create) do |application|
        create(:interview_round, :technical, interview_application: application)
      end
    end

    trait :offer_stage do
      pipeline_stage { :offer }
      applied_at { 1.month.ago }
      ai_summary { "Successful interview process with strong performance" }
    end

    trait :closed_stage do
      pipeline_stage { :closed }
      applied_at { 2.months.ago }
    end
  end
end

