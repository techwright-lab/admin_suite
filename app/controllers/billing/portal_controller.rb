# frozen_string_literal: true

module Billing
  # Controller for redirecting users to the LemonSqueezy customer portal.
  class PortalController < ApplicationController
    # GET /billing/portal
    #
    # Redirects to the LemonSqueezy customer portal for managing payment methods and invoices.
    def show
      customer = Current.user.billing_customers.find_by(provider: "lemonsqueezy")

      unless customer
        redirect_to settings_path(tab: "billing", subtab: "billing"),
          alert: "No billing account found. Please subscribe to a plan first."
        return
      end

      provider = Billing::Providers::LemonSqueezy.new
      url = provider.customer_portal_url(customer: customer)

      redirect_to url, allow_other_host: true
    rescue StandardError => e
      Rails.logger.error("[billing] Failed to get customer portal URL: #{e.message}")
      redirect_to settings_path(tab: "billing", subtab: "billing"),
        alert: "Failed to access billing portal. Please try again or contact support."
    end
  end
end
