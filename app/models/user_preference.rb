# frozen_string_literal: true

# UserPreference model for managing user settings and preferences
class UserPreference < ApplicationRecord
  VIEWS = [ "kanban", "table" ].freeze
  THEMES = [ "light", "dark", "system" ].freeze
  AI_INSIGHTS_FREQUENCIES = [ "daily", "weekly", "on_demand" ].freeze

  belongs_to :user

  # Validations
  validates :user, presence: true, uniqueness: true
  validates :preferred_view, inclusion: { in: VIEWS + [ "list" ] } # Allow "list" for backward compatibility
  validates :theme, inclusion: { in: THEMES }
  validates :ai_insights_frequency, inclusion: { in: AI_INSIGHTS_FREQUENCIES }, allow_nil: true
  validates :data_retention_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Normalize view preference (convert "list" to "table")
  before_validation :normalize_view_preference

  # Returns true if user prefers kanban view
  # @return [Boolean]
  def kanban_view?
    preferred_view == "kanban"
  end

  # Returns true if user prefers table view
  # @return [Boolean]
  def table_view?
    preferred_view == "table" || preferred_view == "list"
  end

  # Returns true if user prefers list view (deprecated, use table_view?)
  # @return [Boolean]
  def list_view?
    table_view?
  end

  # Returns true if AI feedback analysis is enabled
  # @return [Boolean]
  def ai_feedback_analysis?
    ai_feedback_analysis != false
  end

  # Returns true if AI interview prep is enabled
  # @return [Boolean]
  def ai_interview_prep?
    ai_interview_prep != false
  end

  # Returns true if weekly digest emails are enabled
  # @return [Boolean]
  def email_weekly_digest?
    email_weekly_digest != false
  end

  # Returns true if interview reminder emails are enabled
  # @return [Boolean]
  def email_interview_reminders?
    email_interview_reminders != false
  end

  # Returns the effective AI insights frequency, defaulting to weekly
  # @return [String]
  def effective_ai_insights_frequency
    ai_insights_frequency || "weekly"
  end

  # Returns true if data should be retained indefinitely
  # @return [Boolean]
  def retain_data_forever?
    data_retention_days.nil? || data_retention_days == 0
  end

  private

  # Normalize "list" to "table" for consistency
  def normalize_view_preference
    self.preferred_view = "table" if preferred_view == "list"
  end

  # Returns true if dark mode is enabled
  # @return [Boolean]
  def dark_mode?
    theme == "dark"
  end
end
