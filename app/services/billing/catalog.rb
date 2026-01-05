# frozen_string_literal: true

module Billing
  # Read-only access layer for the billing catalog (plans/features/entitlements).
  #
  # This is intentionally cached because it is used by both in-app surfaces and
  # public pricing pages. All catalog models purge this cache on commit so
  # changes in the developer portal reflect immediately.
  class Catalog
    CACHE_KEY = "billing:catalog:v1"
    CACHE_TTL = ENV.fetch("BILLING_CATALOG_CACHE_TTL", 15.seconds).to_i

    class << self
      # Returns published plans ordered for display, including entitlements.
      #
      # @return [Array<Billing::Plan>]
      def published_plans
        cached[:published_plans]
      end

      # Purges cached catalog data.
      #
      # @return [void]
      def purge_cache!
        Rails.cache.delete(CACHE_KEY)
      end

      private

      def cached
        Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
          plans = Billing::Plan.published.ordered.includes(plan_entitlements: :feature).to_a
          { published_plans: plans }
        end
      end
    end
  end
end
