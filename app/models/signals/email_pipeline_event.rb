# frozen_string_literal: true

module Signals
  # Represents a single step/event within an EmailPipelineRun.
  class EmailPipelineEvent < ApplicationRecord
    EVENT_TYPES = [
      :synced_email_upsert,
      :email_classification,
      :company_detection,
      :application_match,
      :signal_extraction_enqueued,

      :legacy_signal_extraction,
      :email_facts_extraction,

      :decision_input_build,
      :decision_plan_build,
      :decision_plan_schema_validate,
      :decision_plan_semantic_validate,

      :execution_dispatch,

      :execute_set_pipeline_stage,
      :execute_set_application_status,
      :execute_create_round,
      :execute_update_round,
      :execute_set_round_result,
      :execute_create_interview_feedback,
      :execute_create_company_feedback,
      :execute_create_opportunity,
      :execute_upsert_job_listing_from_url,
      :execute_attach_job_listing_to_opportunity,
      :execute_enqueue_scrape_job_listing,

      :legacy_orchestrator
    ].freeze

    STATUSES = %i[started success failed skipped].freeze

    belongs_to :run, class_name: "Signals::EmailPipelineRun", inverse_of: :events
    belongs_to :synced_email
    belongs_to :interview_application, optional: true

    enum :event_type, EVENT_TYPES.index_with(&:to_s)
    enum :status, {
      started: 0,
      success: 1,
      failed: 2,
      skipped: 3
    }, default: :started

    validates :event_type, presence: true
    validates :status, presence: true
    validates :step_order, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :in_order, -> { order(step_order: :asc, created_at: :asc) }
    scope :by_type, ->(type) { where(event_type: type) }
    scope :by_status, ->(status) { where(status: status) }
  end
end
