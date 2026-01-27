# frozen_string_literal: true

module Signals
  # Normalized context for signal rule evaluation.
  class StateContext < ApplicationService
    attr_reader :synced_email, :application, :email_type, :extracted_data, :latest_round, :pending_rounds

    def initialize(synced_email)
      @synced_email = synced_email
      @application = synced_email.interview_application
      @email_type = synced_email.email_type.to_s
      @extracted_data = synced_email.extracted_data || {}
      @latest_round = application&.interview_rounds&.ordered&.last
      @pending_rounds = application ? application.interview_rounds.where(result: :pending).order(scheduled_at: :desc) : InterviewRound.none
    end

    def matched?
      synced_email.matched?
    end
  end
end
