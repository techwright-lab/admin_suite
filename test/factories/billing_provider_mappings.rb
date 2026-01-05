# frozen_string_literal: true

FactoryBot.define do
  factory :billing_provider_mapping, class: "Billing::ProviderMapping" do
    association :plan, factory: :billing_plan
    provider { "lemonsqueezy" }
    external_product_id { "prod_1" }
    external_variant_id { "variant_1" }
    external_price_id { nil }
    metadata { { "store_id" => "store_1" } }
  end
end


