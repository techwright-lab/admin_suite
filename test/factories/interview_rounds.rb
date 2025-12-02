FactoryBot.define do
  factory :interview_round do
    association :interview_application
    
    stage { :screening }
    stage_name { "Phone Screen" }
    scheduled_at { 3.days.from_now }
    completed_at { nil }
    duration_minutes { 30 }
    interviewer_name { "Jane Smith" }
    interviewer_role { "Recruiter" }
    notes { "Initial screening call" }
    result { :pending }
    position { 1 }

    trait :screening do
      stage { :screening }
      stage_name { "Phone Screen" }
      duration_minutes { 30 }
      interviewer_role { "Recruiter" }
    end

    trait :technical do
      stage { :technical }
      stage_name { "Technical Interview" }
      duration_minutes { 60 }
      interviewer_role { "Senior Engineer" }
      position { 2 }
    end

    trait :hiring_manager do
      stage { :hiring_manager }
      stage_name { "Hiring Manager Interview" }
      duration_minutes { 45 }
      interviewer_role { "Engineering Manager" }
      position { 3 }
    end

    trait :culture_fit do
      stage { :culture_fit }
      stage_name { "Culture Fit Interview" }
      duration_minutes { 30 }
      interviewer_role { "Team Lead" }
      position { 4 }
    end

    trait :completed do
      completed_at { 1.day.ago }
      result { :passed }
    end

    trait :passed do
      result { :passed }
      completed_at { 1.day.ago }
    end

    trait :failed do
      result { :failed }
      completed_at { 1.day.ago }
    end

    trait :upcoming do
      scheduled_at { 3.days.from_now }
      completed_at { nil }
      result { :pending }
    end
  end
end
