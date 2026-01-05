# frozen_string_literal: true

module Billing
  # Optional return/confirmation page after LemonSqueezy checkout.
  #
  # Note: subscription activation should still rely on webhooks; this page is
  # strictly for UX and support context (order_id/order_identifier).
  class ReturnsController < ApplicationController
    allow_unauthenticated_access only: [ :show ]

    # GET /billing/return
    def show
      @order_id = params[:order_id]
      @order_identifier = params[:order_identifier]
      @email = params[:email]
      @name = params[:name]
      @total = params[:total]
    end
  end
end
