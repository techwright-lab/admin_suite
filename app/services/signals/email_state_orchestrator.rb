# frozen_string_literal: true

require "set"

module Signals
  # Orchestrates processor execution and application state updates.
  class EmailStateOrchestrator < ApplicationService
    PROCESSOR_ACTIONS = %i[
      run_interview_round_processor
      run_round_feedback_processor
      run_status_processor
    ].freeze

    attr_reader :synced_email, :context, :planner

    def initialize(synced_email)
      @synced_email = synced_email
      @context = Signals::StateContext.new(synced_email)
      @planner = Signals::StateTransitionPlanner.new(context)
    end

    def call
      unless context.matched?
        log_info("Skipped email #{synced_email.id}: not matched to application")
        return { success: false, skipped: true, reason: "Email not matched to application" }
      end

      log_info("Processing email #{synced_email.id} (type: #{synced_email.email_type})")
      actions = planner.plan
      processor_actions, state_actions = partition_actions(actions)

      processor_results = run_processors(processor_actions)
      applied_actions = Signals::ActionApplier.new(context).apply!(state_actions)

      {
        success: true,
        actions: actions,
        processor_results: processor_results,
        applied_actions: applied_actions
      }
    rescue StandardError => e
      notify_error(
        e,
        context: "signal_email_orchestrator",
        user: synced_email&.user,
        synced_email_id: synced_email&.id,
        application_id: context.application&.id,
        email_type: synced_email&.email_type
      )
      log_error("Failed to process email #{synced_email&.id}: #{e.message}")
      { success: false, error: e.message }
    end

    private

    def partition_actions(actions)
      processor_actions = actions.select { |action| PROCESSOR_ACTIONS.include?(action[:type]) }
      state_actions = actions.reject { |action| PROCESSOR_ACTIONS.include?(action[:type]) }

      [ dedupe_actions(processor_actions), state_actions ]
    end

    def dedupe_actions(actions)
      seen = Set.new
      actions.each_with_object([]) do |action, list|
        next if seen.include?(action[:type])

        seen << action[:type]
        list << action
      end
    end

    def run_processors(actions)
      actions.each_with_object({}) do |action, results|
        case action[:type]
        when :run_interview_round_processor
          results[:interview_round] = Signals::InterviewRoundProcessor.new(synced_email).process
        when :run_round_feedback_processor
          results[:round_feedback] = Signals::RoundFeedbackProcessor.new(synced_email).process
        when :run_status_processor
          results[:application_status] = Signals::ApplicationStatusProcessor.new(synced_email).process
        end
      end
    end
  end
end
