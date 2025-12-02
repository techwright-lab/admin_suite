# frozen_string_literal: true

# SupportTicket model for contact form submissions
class SupportTicket < ApplicationRecord
  belongs_to :user, optional: true

  validates :name, presence: true
  validates :email, presence: true
  validates :subject, presence: true
  validates :message, presence: true
  validates :status, presence: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  enum :status, {
    open: "open",
    in_progress: "in_progress",
    resolved: "resolved",
    closed: "closed"
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :open_tickets, -> { where(status: [:open, :in_progress]) }
  scope :by_status, ->(status) { where(status: status) if status.present? }

  # Returns display name for the ticket
  # @return [String]
  def display_name
    "#{name} - #{subject}"
  end

  # Checks if ticket is from a registered user
  # @return [Boolean]
  def from_user?
    user.present?
  end

  # Returns a truncated message for display
  # @param length [Integer] Maximum length
  # @return [String]
  def message_preview(length = 100)
    return message if message.length <= length
    "#{message[0...length]}..."
  end
end

