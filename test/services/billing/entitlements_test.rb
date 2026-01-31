# frozen_string_literal: true

require "test_helper"

class Billing::EntitlementsTest < ActiveSupport::TestCase
  test "treats legacy plan keys as aliases for entitlement evaluation" do
    user = create(:user)

    create(:billing_plan, :free)

    canonical_pro = create(:billing_plan, :pro, key: "pro_monthly")
    legacy_pro = create(:billing_plan, key: "pro", name: "Pro (Legacy)", plan_type: "recurring", interval: "month", amount_cents: 1200, currency: "eur", published: false)

    feature = create(:billing_feature, key: "round_prep_access", kind: "boolean")
    create(:billing_plan_entitlement, plan: canonical_pro, feature: feature, enabled: true)
    create(:billing_subscription, user: user, plan: legacy_pro, status: "active", current_period_ends_at: 1.month.from_now)

    ent = Billing::Entitlements.for(user)
    assert_equal canonical_pro, ent.plan
    assert_equal true, ent.allowed?(:round_prep_access)
  end

  test "falls back to free plan and respects plan entitlements" do
    user = create(:user)

    free_plan = create(:billing_plan, :free, published: true)
    feature = create(:billing_feature, key: "pattern_detection", kind: "boolean")
    create(:billing_plan_entitlement, plan: free_plan, feature: feature, enabled: false)

    ent = Billing::Entitlements.for(user)
    assert_equal free_plan, ent.plan
    assert_equal false, ent.allowed?(:pattern_detection)
  end

  test "uses active subscription plan when present" do
    user = create(:user)
    create(:billing_plan, :free)

    pro_plan = create(:billing_plan, :pro)
    feature = create(:billing_feature, key: "pattern_detection", kind: "boolean")
    create(:billing_plan_entitlement, plan: pro_plan, feature: feature, enabled: true)
    create(:billing_subscription, user: user, plan: pro_plan, status: "active", current_period_ends_at: 1.month.from_now)

    ent = Billing::Entitlements.for(user)
    assert_equal pro_plan, ent.plan
    assert_equal true, ent.allowed?(:pattern_detection)
  end

  test "trial grant overrides plan entitlements and quota remaining uses usage counters" do
    user = create(:user)
    create(:billing_plan, :free)

    pro_plan = create(:billing_plan, :pro)
    ai_feature = create(:billing_feature, key: "ai_summaries", kind: "quota")
    create(:billing_plan_entitlement, plan: pro_plan, feature: ai_feature, enabled: true, limit: 10)
    create(:billing_subscription, user: user, plan: pro_plan, status: "active", current_period_ends_at: 1.month.from_now)

    # Override with trial grant (larger limit)
    Billing::EntitlementGrant.create!(
      user: user,
      source: "trial",
      reason: "insight_triggered",
      starts_at: Time.current - 1.minute,
      expires_at: Time.current + 1.day,
      entitlements: { "ai_summaries" => { "enabled" => true, "limit" => 25 } }
    )

    period_start = Time.current.beginning_of_month
    period_end = period_start + 1.month
    Billing::UsageCounter.increment!(user: user, feature_key: "ai_summaries", period_starts_at: period_start, period_ends_at: period_end, delta: 7)

    ent = Billing::Entitlements.for(user)
    assert_equal 25, ent.limit(:ai_summaries)
    assert_equal 18, ent.remaining(:ai_summaries)
  end
end
