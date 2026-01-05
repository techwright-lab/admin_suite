# frozen_string_literal: true

FactoryBot.define do
  factory :billing_plan_entitlement, class: "Billing::PlanEntitlement" do
    association :plan, factory: :billing_plan
    association :feature, factory: :billing_feature
    enabled { true }
    limit { nil }
    metadata { {} }
  end
end


