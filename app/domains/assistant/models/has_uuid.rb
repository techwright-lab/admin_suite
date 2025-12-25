# frozen_string_literal: true

require "securerandom"

module Assistant
  # Adds a stable UUID identifier intended for external references (URLs, logs, admin ops).
  #
  # This keeps the internal integer primary key for joins, while providing a safe identifier
  # that can be shared in logs or used for idempotency keys.
  module HasUuid
    extend ActiveSupport::Concern

    included do
      before_validation :ensure_uuid, on: :create

      validates :uuid, presence: true, uniqueness: true
    end

    def to_param
      uuid
    end

    private

    def ensure_uuid
      self.uuid ||= SecureRandom.uuid
    end
  end
end
