# frozen_string_literal: true

FactoryBot.define do
  factory :billing_entitlement_grant, class: "Billing::EntitlementGrant" do
    user
    source { "trial" }
    reason { "insight_triggered" }
    starts_at { Time.current }
    expires_at { 72.hours.from_now }
    entitlements { {} }
    metadata { {} }

    trait :active do
      starts_at { 1.day.ago }
      expires_at { 2.days.from_now }
    end

    trait :expired do
      starts_at { 5.days.ago }
      expires_at { 2.days.ago }
    end

    trait :with_round_prep do
      entitlements do
        {
          "round_prep_access" => { "enabled" => true },
          "round_prep_generations" => { "enabled" => true, "limit" => 10 }
        }
      end
    end
  end
end
