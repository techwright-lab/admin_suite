# frozen_string_literal: true

require "test_helper"

class Billing::TrialUnlockServiceTest < ActiveSupport::TestCase
  test "unlocks once per user and creates a 72h entitlement grant" do
    user = create(:user)
    create(:billing_plan, :free) # fallback plan in entitlements

    result = Billing::TrialUnlockService.new(user: user, trigger: :first_ai_request).run

    assert_equal true, result[:unlocked]
    assert_instance_of Billing::EntitlementGrant, result[:grant]
    assert_in_delta 72.hours.from_now.to_i, result[:expires_at].to_i, 5

    second = Billing::TrialUnlockService.new(user: user, trigger: :second_attempt).run
    assert_equal false, second[:unlocked]
  end

  test "does not unlock when user has an active subscription" do
    user = create(:user)
    plan = create(:billing_plan, :pro)
    create(:billing_subscription, user: user, plan: plan, status: "active", current_period_ends_at: 1.month.from_now)

    result = Billing::TrialUnlockService.new(user: user, trigger: :first_ai_request).run
    assert_equal false, result[:unlocked]
  end
end


