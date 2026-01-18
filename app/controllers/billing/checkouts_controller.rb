# frozen_string_literal: true

module Billing
  # Starts a hosted checkout for a given plan.
  class CheckoutsController < ApplicationController
    # POST /billing/checkout/:plan_key
    def create
      plan = Billing::Plan.find_by!(key: params[:plan_key])

      # Prepare plan switch (cancel conflicting plans before checkout)
      switcher = Billing::PlanSwitcher.new(Current.user)
      switch_result = switcher.prepare_switch(plan)

      if switch_result[:cancelled_subscription]
        Rails.logger.info(
          "[billing] checkout cancelled existing subscription for plan switch " \
          "user_id=#{Current.user.id} new_plan=#{plan.key}"
        )
      end

      if switch_result[:deactivated_grant]
        Rails.logger.info(
          "[billing] checkout deactivated existing purchase grant for plan switch " \
          "user_id=#{Current.user.id} new_plan=#{plan.key}"
        )
      end

      url = Billing::Providers::LemonSqueezy.new.create_checkout(user: Current.user, plan: plan)

      # Important: LemonSqueezy checkout is on a different origin. If this action is
      # submitted via Turbo (fetch/XHR), the redirect will be blocked by the browser's
      # CORS policy. We also disable Turbo on the checkout forms, but return a 303 to
      # encourage a full navigation.
      redirect_to url, allow_other_host: true, status: :see_other
    rescue ActiveRecord::RecordNotFound
      redirect_to settings_path(tab: "billing"), alert: "Plan not found."
    rescue => e
      ExceptionNotifier.notify(e, context: "payment", severity: "error", user: { id: Current.user&.id, email: Current.user&.email_address }, plan_key: params[:plan_key])
      redirect_to settings_path(tab: "billing"), alert: "Could not start checkout. Please try again."
    end
  end
end
