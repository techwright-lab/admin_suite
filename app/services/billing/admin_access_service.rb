# frozen_string_literal: true

module Billing
  # Grants/revokes internal Admin/Developer access (all features enabled).
  #
  # Implementation notes:
  # - Entitlement grants require an expires_at, so "no restriction" is represented
  #   as a far-future expiry.
  # - The grant entitlements are expanded to include all known Billing::Feature keys,
  #   so the gating layer does not need wildcard logic.
  class AdminAccessService
    FAR_FUTURE_EXPIRY = 100.years

    # @param user [User]
    # @param actor [User, nil]
    def initialize(user:, actor: nil)
      @user = user
      @actor = actor
    end

    # @return [Billing::EntitlementGrant]
    def grant!
      existing = active_admin_grant
      return existing if existing.present?

      Billing::EntitlementGrant.create!(
        user: user,
        source: "admin",
        reason: "admin_developer",
        starts_at: Time.current,
        expires_at: Time.current + FAR_FUTURE_EXPIRY,
        entitlements: build_all_entitlements,
        metadata: {
          granted_by_user_id: actor&.id,
          granted_by_email: actor&.email_address
        }.compact
      )
    end

    # @return [Integer] number of grants revoked
    def revoke!
      grants = Billing::EntitlementGrant.active_at(Time.current).where(user: user, source: "admin", reason: "admin_developer")
      now = Time.current

      grants.each do |g|
        # Keep the window valid: expires_at must remain > starts_at.
        min_expiry = g.starts_at + 1.second
        g.update!(expires_at: [ now, min_expiry ].max)
      end

      grants.size
    end

    # @return [Boolean]
    def active?
      active_admin_grant.present?
    end

    private

    attr_reader :user, :actor

    def active_admin_grant
      Billing::EntitlementGrant.active_at(Time.current).find_by(user: user, source: "admin", reason: "admin_developer")
    end

    def build_all_entitlements
      Billing::Feature.all.each_with_object({}) do |feature, h|
        # For quota features, set limit to nil (unlimited)
        # This explicitly overrides any base plan limits
        if feature.kind == "quota"
          h[feature.key] = { "enabled" => true, "limit" => nil }
        else
          h[feature.key] = { "enabled" => true }
        end
      end
    end
  end
end
