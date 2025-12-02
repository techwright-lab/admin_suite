FactoryBot.define do
  factory :user_target_job_role do
    association :user
    association :job_role
    priority { 1 }

    trait :high_priority do
      priority { 1 }
    end

    trait :low_priority do
      priority { 10 }
    end
  end
end
