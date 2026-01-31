# frozen_string_literal: true

require "test_helper"

class Billing::AdminAccessServiceTest < ActiveSupport::TestCase
  test "grant! refreshes existing admin grant entitlements for newly-added features" do
    user = create(:user)

    # Ensure there are some known features to expand into the admin grant.
    create(:billing_feature, key: "round_prep_access", kind: "boolean", name: "Round prep access")
    create(:billing_feature, key: "round_prep_generations", kind: "quota", unit: "generations", name: "Round prep generations")

    existing = Billing::EntitlementGrant.create!(
      user: user,
      source: "admin",
      reason: "admin_developer",
      starts_at: 1.day.ago,
      expires_at: 1.day.from_now,
      entitlements: { "some_old_key" => { "enabled" => true } }
    )

    Billing::AdminAccessService.new(user: user).grant!
    existing.reload

    assert_equal true, existing.entitlements.dig("round_prep_access", "enabled")
    assert_equal true, existing.entitlements.dig("round_prep_generations", "enabled")
    assert_nil existing.entitlements.dig("round_prep_generations", "limit")
  end
end
