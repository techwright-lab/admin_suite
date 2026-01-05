# frozen_string_literal: true

module Public
  # Public pricing page.
  class PricingController < BaseController
    # GET /pricing
    def show
      @plans = Billing::Catalog.published_plans
    end
  end
end


