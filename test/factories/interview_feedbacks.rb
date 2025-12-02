# frozen_string_literal: true

FactoryBot.define do
  factory :interview_feedback do
    association :interview_round
    went_well { "Technical questions were handled well. Good communication with the interviewer." }
    to_improve { "Could have asked more clarifying questions about the role." }
    interviewer_notes { "Strong technical skills, good culture fit" }
    self_reflection { "Overall felt confident, but need to work on asking better questions." }
    tags { ["Communication", "Technical Skills", "Problem Solving"] }
    ai_summary { "Strong performance with room for improvement in question-asking" }
    recommended_action { "Practice asking clarifying questions in mock interviews" }

    trait :positive do
      went_well { "Excellent performance across all areas. Connected well with the team." }
      to_improve { nil }
      ai_summary { "Outstanding interview with all positive indicators" }
    end

    trait :needs_improvement do
      went_well { "Showed up on time and was prepared" }
      to_improve { "Need to work on technical depth and system design skills" }
      ai_summary { "Several areas identified for improvement, particularly in technical depth" }
      recommended_action { "Focus on system design study and practice coding challenges" }
    end

    trait :minimal do
      went_well { "Good conversation" }
      to_improve { nil }
      interviewer_notes { nil }
      self_reflection { nil }
      tags { [] }
      ai_summary { nil }
      recommended_action { nil }
    end
  end
end

