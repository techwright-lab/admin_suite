# frozen_string_literal: true

module Signals
  # Represents a single end-to-end processing run for a SyncedEmail.
  #
  # Mirrors the ScrapingAttempt/ScrapingEvent pattern, but for the email → signals pipeline.
  class EmailPipelineRun < ApplicationRecord
    STATUSES = %i[started success failed].freeze

    belongs_to :synced_email
    belongs_to :user
    belongs_to :connected_account

    has_many :events,
      class_name: "Signals::EmailPipelineEvent",
      foreign_key: :run_id,
      inverse_of: :run,
      dependent: :destroy

    enum :status, {
      started: 0,
      success: 1,
      failed: 2
    }, default: :started

    validates :status, presence: true
    validates :trigger, presence: true
    validates :mode, presence: true
    validates :started_at, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :by_status, ->(status) { where(status: status) }

    def next_step_order
      events.maximum(:step_order).to_i + 1
    end
  end
end
