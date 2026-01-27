# frozen_string_literal: true

module Signals
  # Evaluates rules and emits ordered actions.
  class StateTransitionPlanner < ApplicationService
    attr_reader :context, :rules

    def initialize(context, rules: default_rules)
      @context = context
      @rules = rules
    end

    def plan
      applicable = rules.select { |rule| rule.safe_applies?(context) }
      applicable.sort_by(&:priority).reverse.flat_map { |rule| rule.safe_actions(context) }
    rescue StandardError => e
      notify_error(
        e,
        context: "signal_state_planner",
        user: context.synced_email&.user,
        synced_email_id: context.synced_email&.id,
        application_id: context.application&.id
      )
      log_error("Failed to plan actions for email #{context.synced_email&.id}: #{e.message}")
      []
    end

    private

    def default_rules
      [
        Rules::RejectionRule.new,
        Rules::OfferRule.new,
        Rules::RoundFeedbackRule.new,
        Rules::SchedulingRule.new,
        Rules::ApplicationConfirmationRule.new
      ]
    end
  end
end
