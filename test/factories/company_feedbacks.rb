FactoryBot.define do
  factory :company_feedback do
    association :interview_application
    
    feedback_text { "Thank you for your interest. We've decided to move forward with other candidates." }
    received_at { 1.week.ago }
    rejection_reason { nil }
    next_steps { nil }
    self_reflection { "Good learning experience" }

    trait :with_rejection do
      rejection_reason { "Not enough experience with required technologies" }
      feedback_text { "We appreciate your time but have decided to pursue other candidates with more relevant experience." }
    end

    trait :with_next_steps do
      next_steps { "Schedule follow-up interview with hiring manager" }
      feedback_text { "Great first interview! We'd like to move forward to the next round." }
    end

    trait :positive do
      feedback_text { "Excellent performance throughout the interview process. We're excited to extend an offer." }
      next_steps { "HR will reach out with offer details" }
    end
  end
end
