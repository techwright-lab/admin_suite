# frozen_string_literal: true

# InterviewPrepArtifact stores cached, structured interview prep content for a specific application.
#
# Artifacts are generated per section (kind) and are idempotent via inputs_digest.
class InterviewPrepArtifact < ApplicationRecord
  KINDS = [ :match_analysis, :focus_areas, :question_framing, :strength_positioning ].freeze
  STATUSES = [ :pending, :computed, :failed ].freeze

  belongs_to :interview_application
  belongs_to :user
  belongs_to :llm_api_log, class_name: "Ai::LlmApiLog", optional: true

  enum :kind, KINDS
  enum :status, STATUSES, default: :pending

  validates :uuid, presence: true, uniqueness: true
  validates :kind, presence: true, inclusion: { in: KINDS.map(&:to_s) }
  validates :status, presence: true, inclusion: { in: STATUSES.map(&:to_s) }
  validates :inputs_digest, presence: true

  validate :application_owned_by_user

  before_validation :ensure_uuid, on: :create

  scope :recent_first, -> { order(updated_at: :desc, created_at: :desc) }

  private

  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def application_owned_by_user
    return if interview_application.nil? || user.nil?
    return if interview_application.user_id == user_id

    errors.add(:user, "must match the interview application's owner")
  end
end
