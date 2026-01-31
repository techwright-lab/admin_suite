# frozen_string_literal: true

module Signals
  # Applies planned actions in deterministic order.
  class ActionApplier < ApplicationService
    ACTION_ORDER = [
      :mark_latest_round_failed,
      :sync_application_from_round_result,
      :set_application_status,
      :set_pipeline_stage,
      :sync_pipeline_from_round_stage
    ].freeze

    def initialize(context)
      @context = context
      @application = context.application
    end

    def apply!(actions)
      return [] if actions.blank? || @application.blank?

      applied = []
      ordered = actions.sort_by { |action| ACTION_ORDER.index(action[:type]) || ACTION_ORDER.length }

      @application.reload
      ordered.each do |action|
        case action[:type]
        when :mark_latest_round_failed
          applied << apply_mark_latest_round_failed
        when :sync_application_from_round_result
          applied << apply_application_from_round_result
        when :set_application_status
          applied << apply_application_status(action[:status])
        when :set_pipeline_stage
          applied << apply_pipeline_stage(action[:stage])
        when :sync_pipeline_from_round_stage
          applied << apply_pipeline_from_round_stage
        end
      end

      applied.compact
    rescue StandardError => e
      notify_error(
        e,
        context: "signal_action_applier",
        user: @context.synced_email&.user,
        synced_email_id: @context.synced_email&.id,
        application_id: @application&.id
      )
      log_error("Failed to apply actions for email #{@context.synced_email&.id}: #{e.message}")
      []
    end

    private

    def apply_mark_latest_round_failed
      round = pending_rounds.first || latest_round
      return nil unless round&.result == "pending"

      round.update!(result: :failed, completed_at: Time.current)
      { type: :mark_latest_round_failed, round_id: round.id }
    end

    def apply_application_from_round_result
      round = latest_round || pending_rounds.first
      return nil unless round

      case round.result
      when "failed"
        apply_application_status(:rejected)
        apply_pipeline_stage(:closed)
      when "passed", "waitlisted"
        apply_pipeline_stage(:interviewing)
      end
    end

    def apply_application_status(status)
      case status&.to_sym
      when :rejected
        return nil unless @application.may_reject?
        @application.reject!
      when :accepted
        return nil unless @application.may_accept?
        @application.accept!
      when :archived
        return nil unless @application.may_archive?
        @application.archive!
      when :on_hold
        return nil unless @application.respond_to?(:may_hold?) && @application.may_hold?
        @application.hold!
      when :withdrawn
        return nil unless @application.respond_to?(:may_withdraw?) && @application.may_withdraw?
        @application.withdraw!
      when :active
        return nil unless @application.may_reactivate?
        @application.reactivate!
      end

      { type: :set_application_status, status: @application.status }
    end

    def apply_pipeline_stage(stage)
      event_method = case stage&.to_sym
      when :screening then :move_to_screening
      when :interviewing then :move_to_interviewing
      when :offer then :move_to_offer
      when :closed then :move_to_closed
      when :applied then :move_to_applied
      end

      return nil unless event_method
      return nil unless @application.aasm(:pipeline_stage).may_fire_event?(event_method)

      @application.send("#{event_method}!")
      { type: :set_pipeline_stage, stage: @application.pipeline_stage }
    end

    def apply_pipeline_from_round_stage
      round = latest_round
      return nil unless round

      target_stage = round.stage == "screening" ? :screening : :interviewing
      apply_pipeline_stage(target_stage)
    end

    def latest_round
      @application.interview_rounds.ordered.last
    end

    def pending_rounds
      @application.interview_rounds.where(result: :pending).order(scheduled_at: :desc)
    end
  end
end
