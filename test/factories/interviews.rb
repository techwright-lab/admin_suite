# frozen_string_literal: true

FactoryBot.define do
  factory :interview do
    association :user
    company { "TechCorp Inc" }
    role { "Software Engineer" }
    stage { :applied }
    date { 1.week.from_now }
    status { "Applied" }
    notes { "Excited about this opportunity" }

    trait :with_feedback do
      after(:create) do |interview|
        create(:feedback_entry, interview: interview)
      end
    end

    trait :with_skills do
      after(:create) do |interview|
        skills = create_list(:skill_tag, 3)
        interview.skill_tags << skills
      end
    end

    trait :applied do
      stage { :applied }
      status { "Awaiting response" }
    end

    trait :interview_stage do
      stage { :interview }
      status { "Interview scheduled" }
      date { 3.days.from_now }
    end

    trait :feedback_stage do
      stage { :feedback }
      status { "Awaiting feedback" }
      date { 1.week.ago }
    end

    trait :offer_stage do
      stage { :offer }
      status { "Offer received" }
      date { 2.weeks.ago }
      ai_summary { "Successful interview process with strong performance" }
    end
  end
end

