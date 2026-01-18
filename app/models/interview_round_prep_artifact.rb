# frozen_string_literal: true

# InterviewRoundPrepArtifact model for storing AI-generated interview preparation content.
#
# Each artifact stores a specific type of prep content (questions, strategies, patterns, tips)
# for a specific interview round. Uses inputs_digest for cache invalidation.
#
# @example
#   artifact = InterviewRoundPrepArtifact.create!(
#     interview_round: round,
#     kind: :comprehensive,
#     content: { questions: [...], strategies: [...] },
#     status: :completed
#   )
class InterviewRoundPrepArtifact < ApplicationRecord
  # Artifact kinds - types of prep content
  KINDS = [ :comprehensive, :questions, :strategies, :patterns, :tips, :checklist ].freeze

  # Status values for generation workflow
  STATUSES = [ :pending, :generating, :completed, :failed ].freeze

  # Associations
  belongs_to :interview_round

  # Enums
  enum :status, STATUSES, default: :pending

  # Validations
  validates :interview_round, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS.map(&:to_s) }
  validates :kind, uniqueness: { scope: :interview_round_id, message: "already exists for this round" }

  # Store accessors for common content fields
  store_accessor :content,
    :round_summary,
    :expected_questions,
    :your_history,
    :company_patterns,
    :preparation_checklist,
    :answer_strategies,
    :tips

  # Scopes
  scope :by_kind, ->(kind) { where(kind: kind) }
  scope :completed, -> { where(status: :completed) }
  scope :recent, -> { order(generated_at: :desc) }

  # Checks if the artifact is stale based on inputs
  #
  # @param new_digest [String] The digest of current inputs
  # @return [Boolean] True if stale and needs regeneration
  def stale?(new_digest)
    inputs_digest != new_digest
  end

  # Marks the artifact as completed with content
  #
  # @param new_content [Hash] The generated content
  # @param digest [String] The inputs digest for cache invalidation
  # @return [Boolean] True if save succeeded
  def complete!(new_content, digest: nil)
    self.content = new_content
    self.inputs_digest = digest if digest
    self.generated_at = Time.current
    self.status = :completed
    save!
  end

  # Marks the artifact as failed
  #
  # @param error_message [String] Optional error message to store
  # @return [Boolean] True if save succeeded
  def fail!(error_message = nil)
    self.content = { error: error_message } if error_message
    self.status = :failed
    save!
  end

  # Returns the display name for the artifact kind
  #
  # @return [String] Human-readable kind name
  def kind_display_name
    kind.to_s.titleize
  end

  # Checks if the artifact has usable content
  #
  # @return [Boolean] True if completed with content
  def has_content?
    completed? && content.present? && !content.key?("error")
  end

  # Finds or initializes an artifact for a round and kind
  #
  # @param interview_round [InterviewRound] The round
  # @param kind [Symbol, String] The artifact kind
  # @return [InterviewRoundPrepArtifact] Found or new artifact
  def self.find_or_initialize_for(interview_round:, kind:)
    find_or_initialize_by(interview_round: interview_round, kind: kind)
  end
end
