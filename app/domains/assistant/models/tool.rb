# frozen_string_literal: true

module Assistant
  # Tool registry entry (admin-managed).
  class Tool < ApplicationRecord
    self.table_name = "assistant_tools"

    RISK_LEVELS = %w[read_only write_low write_high].freeze

    validates :tool_key, presence: true, uniqueness: true
    validates :name, presence: true
    validates :description, presence: true
    validates :risk_level, presence: true, inclusion: { in: RISK_LEVELS }
    validates :executor_class, presence: true

    scope :enabled, -> { where(enabled: true) }
    scope :by_key, -> { order(:tool_key) }
  end
end
