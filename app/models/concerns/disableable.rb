# frozen_string_literal: true

# Adds a soft-disable mechanism to a model via a `disabled_at` timestamp.
#
# Usage:
#   class Company < ApplicationRecord
#     include Disableable
#   end
#
# Provides:
# - `enabled` / `disabled` scopes
# - `disabled?`
# - `disable!` / `enable!`
module Disableable
  extend ActiveSupport::Concern

  included do
    scope :enabled, -> { where(disabled_at: nil) }
    scope :disabled, -> { where.not(disabled_at: nil) }
  end

  def disabled?
    disabled_at.present?
  end

  def disable!
    update!(disabled_at: Time.current)
  end

  def enable!
    update!(disabled_at: nil)
  end
end
