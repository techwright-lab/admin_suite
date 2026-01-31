# frozen_string_literal: true

require "test_helper"

class Billing::DebugSnapshotServiceTest < ActiveSupport::TestCase
  test "returns a snapshot hash without raising" do
    user = create(:user)
    create(:billing_plan, :free) # fallback for entitlements

    create(:billing_feature, key: "round_prep_access", kind: "boolean")
    create(:billing_feature, :quota, key: "round_prep_generations", unit: "generations")

    snapshot = Billing::DebugSnapshotService.new(user: user).run

    assert snapshot[:generated_at].present?
    assert snapshot.dig(:entitlements, :features, "round_prep_access").present?
    assert snapshot.dig(:entitlements, :features, "round_prep_generations").present?
  end
end
